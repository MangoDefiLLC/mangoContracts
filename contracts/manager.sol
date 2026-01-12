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
    // Note: teamFee, buyAndBurnFee, referralFee are uint16 for storage packing (gas optimization)
    // They store the percentage/amount allocated to each category, reset to 0 after distribution
    // totalFeesCollected (uint256) stores the complete accumulated value of all fees
    uint16 public teamFee;        // Storage packed - stores allocated amount, resets after withdrawal
    uint16 public buyAndBurnFee;  // Storage packed - stores allocated amount, resets after burn
    uint16 public referralFee;    // Storage packed - stores allocated amount, resets after funding
    uint256 public totalFeesCollected;// Stores complete accumulated value of all fees
    uint256 public totalBurned;


    event FeesReceived(uint256 indexed totalAmount);
    event TeamFeeWithdrawn(address indexed owner, uint256 indexed amount);

    constructor(
        IMangoStructs.cManagerParams memory params
        ) 
        Ownable(){
        if(params.mangoRouter == address(0)) revert IMangoErrors.InvalidAddress();
        if(params.mangoReferral == address(0)) revert IMangoErrors.InvalidAddress();
        if(params.token == address(0)) revert IMangoErrors.InvalidAddress();
        
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
        if(amount > uint256(buyAndBurnFee)) revert IMangoErrors.AmountExceedsFee();

        // Track balance before purchase to only burn newly purchased tokens
        uint256 balanceBefore = mangoToken.balanceOf(address(this));
        _buyMango(amount);
        uint256 balanceAfter = mangoToken.balanceOf(address(this));
        uint256 purchasedAmount = balanceAfter - balanceBefore;
        
        // Only burn the tokens purchased in this transaction
        mangoToken.burn(purchasedAmount);

        unchecked {
            // Safe: amount <= buyAndBurnFee (validated above)
            buyAndBurnFee -= uint16(amount);
            // Safe: totalBurned is uint256, amount is bounded by buyAndBurnFee (uint16 max)
            totalBurned += amount;
        }
    }
    /**
     * @notice Funds the referral contract with MANGO tokens using accumulated referralFee
     * @dev Purchases MANGO tokens with ETH from referralFee and deposits them into the referral contract
     * @param amount Amount of ETH (in wei) to use for purchasing and funding tokens
     * @custom:security Only owner can call. Ensures referral contract has sufficient tokens for rewards.
     */
    function fundReferral(uint256 amount)external{
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        if(amount > uint256(referralFee)) revert IMangoErrors.AmountExceedsFee();

        _buyMango(amount);
        //@NOTE:
        // if the referral has more tokens than the amount we just purchase
        // risk of sending all to referral
        //@dev: for ow this contract deals only with eth
        // Optimized: Cache addresses to avoid repeated reads
        address tokenAddress = address(mangoToken);
        uint256 amountOut = mangoToken.balanceOf(address(this));
        address referralAddress = address(mangoReferral);
    
        (bool s,) = referralAddress.call(
            abi.encodeWithSignature(
                "depositTokens(address,uint256)", // Fixed typo: depositeTokens -> depositTokens
                tokenAddress,
                amountOut
            )
        );
        if(!s) revert IMangoErrors.ReferralFundingFailed();
        unchecked {
            // Safe: amount <= referralFee (validated above)
            referralFee -= uint16(amount);
        }
        //send Mango tokens to referral
        //call deposite on referral
    }
  
    function _buyMango(uint256 amount) private returns(uint256){
        //making a low level call to foward al gass fees
        // Optimized: Cache addresses to avoid repeated reads
        address routerAddress = address(mangoRouter);
        address tokenAddress = address(mangoToken);
        (bool s,bytes memory amountOut) = routerAddress.call{value:amount}(
            abi.encodeWithSignature("swap(address,address,uint256,address)",address(0),tokenAddress,0,address(0))
        );
        if(!s) revert IMangoErrors.SwapFailed();
        return abi.decode(amountOut,(uint256));
    }

    //of the amount comming in is the 3% fee wish is divided by 3 (1% each)
    // Note: Fees are stored as uint16 for storage packing. They represent allocated amounts
    // that are distributed and reset to 0. totalFeesCollected stores the complete value.
    function _setFees(uint256 amount) private {
        uint256 fee = amount / 3; // Simple division
        
        unchecked {
            // Safe: fee * 3 <= amount by definition of integer division
            uint256 remainder = amount - (fee * 3); // Handle remainder
            
            // Safe: fee comes from division (amount / 3), cannot exceed amount
            // uint16 max is 65,535, which is much larger than typical fee amounts
            teamFee += uint16(fee);
            buyAndBurnFee += uint16(fee);
            // Safe: fee + remainder <= amount (since remainder = amount - fee*3)
            referralFee += uint16(fee + remainder); // Give remainder to referral
        }
    }
    receive() external payable {
        unchecked {
            // Safe: totalFeesCollected is uint256, msg.value is bounded by block gas limit
            // In practice, msg.value will never overflow uint256
            totalFeesCollected += msg.value;
        }
        _setFees(msg.value);
        emit FeesReceived(msg.value);
    }
    function withdrawTeamFee(uint256 amount) external{
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        if(amount > uint256(teamFee)) revert IMangoErrors.AmountExceedsFee();
        if(address(this).balance < amount) revert IMangoErrors.InsufficientBalance();
        
        unchecked {
            // Safe: amount <= teamFee (validated above)
            teamFee -= uint16(amount);
        }
        (bool s,) = msg.sender.call{value:amount}("");
        if(!s) revert IMangoErrors.WithdrawalFailed();
        
        emit TeamFeeWithdrawn(msg.sender, amount);
    }
}