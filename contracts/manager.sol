// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {IMangoRouter} from '../contracts/interfaces/IMangoRouter.sol';
import {MANGO_DEFI_TOKEN} from '../contracts/mangoToken.sol';
import {IMangoReferral} from '../contracts/interfaces/IMangoReferral.sol';
import {IMangoStructs} from '../contracts/interfaces/IMangoStructs.sol';
import { IMangoErrors } from '../contracts/interfaces/IMangoErrors.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**THIS MODULE IS MENT TO MANAGE FEES FROM MANGO ROUTER AND TOKENS TAX
FUNCTIONS:
* BUY AND BURN - BUY X AMOUNT OF THE HOLDING AND BURN
* SEND X AMOUNT OF HOLDING TO OWNER
* buy and fund the referral
@STATE VARS:
- teamFee - amount of fee colelcted for corp
- buyAndBurnFee -  amount of eth avaliable to buy and burn
- referralFee - amount of eth to buy and fund the referral
 */
contract Mango_Manager is Ownable {
    using SafeMath for uint256;

    IMangoRouter public mangoRouter;
    MANGO_DEFI_TOKEN public mangoToken;
    IMangoReferral public mangoReferral;

    //fees commming in have to be separates in to 3 vars
    uint256 public teamFee;
    uint256 public buyAndBurnFee;
    uint256 public referralFee;
    uint256 public totalFeesCollected;
    uint256 public totalBurned;
    uint256 public constant BASIS_POINTS = 10000;

    event FeesReceived(uint256 totalAmount);

    constructor(
        IMangoStructs.cManagerParams memory params
        ) 
        Ownable(){
        mangoRouter = IMangoRouter(params.mangoRouter);
        mangoReferral = IMangoReferral(params.mangoReferral);
        mangoToken = IERC20(params.token);
    }

    function burn(uint256 amount) external onlyOwner{
        //should i make this external?
        //or only owner
        if(msg.sender != owner()) revert IMangoStructs.NotOwner();
        if(amount > buyAndBurnFee) revert IMangoErrors.AmountExceedsFee();

        _buyMango(amount);
        //call the burn function in the erc20 token contract
        mangoToken.burn(amount);

        buyAndBurnFee -= amount;
        totalBurned += amount;
    }
    function fundReferral(uint256 amount)external{
        if(msg.sender != owner()) revert IMangoStructs.NotOwner();
        if(amount > referralFee) revert IMangoErrors.AmountExceedsFee();

        _buyMango(amount);
        referralFee -= amount;
        //send Mango tokens to referral
        //call deposite on referral
    }
  
    function _buyMango(uint256 amount) private returns(uint256){
        //making a low level call to foward al gass fees
        (bool s,) = address(mangoRouter).call{value:amount}(
            abi.encodeWithSignature("swap(address,address,uint256,address)",address(0),address(mangoToken),0,address(0))
        );
        if(!s) revert IMangoErrors.SwapFailed();
    }

    //of the amount comming in is the 3% fee wish is divided by 3 (1% each)
    function _setFees(uint256 amount) private {
        uint256 fee = (amount*BASIS_POINTS) / 3 / BASIS_POINTS;
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
    function withdrawTeamFee() external{
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        (bool s,) = msg.sender.call{value:teamFee}("");
        if(!s) revert IMangoErrors.WithdrawalFailed();
    }
    function withdrawEth(uint256 amount) external{
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        (bool s,) = msg.sender.call{value:amount}("");
        if(!s) revert IMangoErrors.WithdrawalFailed();
    }
}