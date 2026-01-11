// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {IMangoRouter} from '../contracts/interfaces/IMangoRouter.sol';
import {MANGO_DEFI_TOKEN} from '../contracts/mangoToken.sol';
import {IMangoReferral} from '../contracts/interfaces/IMangoReferral.sol';
import {IMangoStructs} from '../contracts/interfaces/IMangoStructs.sol';
import { IMangoErrors } from '../contracts/interfaces/IMangoErrors.sol';
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

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
    uint16 public teamFee;
    uint16 public buyAndBurnFee;
    uint16 public referralFee;
    uint256 public totalFeesCollected;//slot 7
    uint256 public totalBurned;
    uint256 public constant BASIS_POINTS = 10000;

    event FeesReceived(uint256 totalAmount);

    constructor(
        IMangoStructs.cManagerParams memory params
        ) 
        Ownable(){
        mangoRouter = IMangoRouter(params.mangoRouter);
        mangoReferral = IMangoReferral(params.mangoReferral);
        mangoToken = MANGO_DEFI_TOKEN(params.token);
    }

    function burn(uint256 amount) external {
        //should i make this external?
        //or only owner
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        if(amount > buyAndBurnFee) revert IMangoErrors.AmountExceedsFee();
        //burn amount of tokens aquired
        uint256 amountToBurn = _buyMango(amount);
     
        //call the burn function in the erc20 token contract
        mangoToken.burn(amountToBurn);

        buyAndBurnFee -= uint16(amount);
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
                "function depositeTokens(address token, uint256 amount)",
            address(mangoToken),
            amountOut
            )
        );
        if(!s) revert IMangoErrors.ReferralFundingFailed();
        referralFee -= uint16(amount);
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
        uint16 fee = uint16((amount*BASIS_POINTS) / 3 / BASIS_POINTS);
        teamFee = fee;
        buyAndBurnFee = fee;
        referralFee = fee;
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
        (bool s,) = msg.sender.call{value:amount}("");
        if(!s) revert IMangoErrors.WithdrawalFailed();
    }
}