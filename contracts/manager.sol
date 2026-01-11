// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {IMangoRouter} from '../contracts/interfaces/IMangoRouter.sol';
import {MANGO_DEFI_TOKEN} from '../contracts/mangoToken.sol';
import {IMangoReferral} from '../contracts/interfaces/IMangoReferral.sol';
import {IMangoStructs} from '../contracts/interfaces/IMangoStructs.sol';
import { IMangoErrors } from '../contracts/interfaces/IMangoErrors.sol';
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

//THIS MODULE IS MENT TO MANAGE FEES FROM MANGO ROUTER AND TOKENS TAX
//FUNCTIONS:
//BUY AND BURN :BUY X AMOUNT OF THE HOLDING AND BURN
//SEND X AMOUNT OF HOLDING TO OWNER
//buy and fund the referral
//@STATE VARS:
//teamFee //amount of fee colelcted for corp
//buyAndBurnFee // amount of eth avaliable to buy and burn
//referralFee //amount of eth to buy and fund the referral
 
contract Mango_Manager is Ownable, ReentrancyGuard {

    IMangoRouter public mangoRouter;
    MANGO_DEFI_TOKEN public mangoToken;
    IMangoReferral public mangoReferral;

    //fees commming in have to be separates in to 3 vars
    uint256 public teamFee;        // Can store up to 2^256 - 1
    uint256 public buyAndBurnFee;  // Can store up to 2^256 - 1
    uint256 public referralFee;    // Can store up to 2^256 - 1
    uint256 public totalFeesCollected;//slot 7
    uint256 public totalBurned;


    event FeesReceived(uint256 indexed totalAmount);
    event TeamFeeWithdrawn(address indexed owner, uint256 indexed amount);

    constructor(
        IMangoStructs.cManagerParams memory params
        ) 
        Ownable(){
        require(params.mangoRouter != address(0), "Invalid router");
        require(params.mangoReferral != address(0), "Invalid referral");
        require(params.token != address(0), "Invalid token");
        
        mangoRouter = IMangoRouter(params.mangoRouter);
        mangoReferral = IMangoReferral(params.mangoReferral);
        mangoToken = MANGO_DEFI_TOKEN(params.token);
    }

    /**
     * @notice Burns MANGO tokens using accumulated buyAndBurnFee
     * @dev Purchases MANGO tokens with ETH from buyAndBurnFee, then burns only the newly purchased tokens.
     *      This ensures that any tokens accidentally sent to the contract are not burned.
     * @param amount Amount of ETH (in wei) to use for purchasing and burning tokens
     * @custom:security Only owner can call. Only burns tokens purchased in this transaction.
     */
    function burn(uint256 amount) external {
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        if(amount > buyAndBurnFee) revert IMangoErrors.AmountExceedsFee();

        // Track balance before purchase to only burn newly purchased tokens
        uint256 balanceBefore = mangoToken.balanceOf(address(this));
        _buyMango(amount);
        uint256 balanceAfter = mangoToken.balanceOf(address(this));
        uint256 purchasedAmount = balanceAfter - balanceBefore;
        
        // Only burn the tokens purchased in this transaction
        mangoToken.burn(purchasedAmount);

        buyAndBurnFee -= amount;
        totalBurned += amount;
    }
    function fundReferral(uint256 amount)external{
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        if(amount > referralFee) revert IMangoErrors.AmountExceedsFee();

        _buyMango(amount);
        //@NOTE:
        // if the referral has more tokens than the amount we just purchase
        // risk of sending all to referral
        //@dev: for ow this contract deals only with eth
        uint256 amountOut = mangoToken.balanceOf(address(this));
    
        (bool s,) = address(mangoReferral).call(
            abi.encodeWithSignature(
                "depositeTokens(address,uint256)", // Fixed signature (no spaces, no 'function' keyword)
                address(mangoToken),
                amountOut
            )
        );
        if(!s) revert IMangoErrors.ReferralFundingFailed();
        referralFee -= amount;
        //send Mango tokens to referral
        //call deposite on referral
    }
  
    function _buyMango(uint256 amount) private returns(uint256){
        //making a low level call to foward al gass fees
        (bool s,bytes memory amountOut) = address(mangoRouter).call{value:amount}(
            abi.encodeWithSignature("swap(address,address,uint256,address)",address(0),address(mangoToken),0,address(0))
        );
        if(!s) revert IMangoErrors.SwapFailed();
        return abi.decode(amountOut,(uint256));
    }

    //of the amount comming in is the 3% fee wish is divided by 3 (1% each)
    function _setFees(uint256 amount) private {
        uint256 fee = amount / 3; // Simple division
        uint256 remainder = amount - (fee * 3); // Handle remainder
        
        teamFee += fee;
        buyAndBurnFee += fee;
        referralFee += (fee + remainder); // Give remainder to referral
        // // Final check
        //assert(teamFee + buyAndBurnFee + referralFee == amount);
    }
    receive() external payable {
        totalFeesCollected += msg.value;
        _setFees(msg.value);
        emit FeesReceived(msg.value);
    }
    function withdrawTeamFee(uint256 amount) external{
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        require(amount <= teamFee, "Amount exceeds available team fee");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        teamFee -= amount;
        (bool s,) = msg.sender.call{value:amount}("");
        if(!s) revert IMangoErrors.WithdrawalFailed();
        
        emit TeamFeeWithdrawn(msg.sender, amount);
    }
}