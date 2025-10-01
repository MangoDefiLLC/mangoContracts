// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {IMangoRouter} from '../contracts/interfaces/IMangoRouter.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IMangoReferral} from '../contracts/interfaces/IMangoReferral.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**THIS MODULE IS MENT TO MANAGE FEES FROM MANGO ROUTER AND TOKENS TAX
FUNCTIONS:
* BUY AND BURN - BUY X AMOUNT OF THE HOLDING AND BURN
* SEND X AMOUNT OF HOLDING TO OWNER
* TRACK TOKEN TAXES */
contract Mango_Manager is Ownable{
    using SafeMath for uint256;

    IMangoRouter public mangoRouter;
    IERC20 public mangoToken;
    IMangoReferral public mangoReferral;

    //fees commming in have to be separates in to 3 vars
    uint256 public teamFee;
    uint256 public buyAndBurnFee;
    uint256 public referralFee;
    uint256 public totalFeesCollected;
    uint256 public totalBurned;

    error NotOwner();
    error SwapFailed();

    event FeesReceived(uint256 totalAmount, uint256 teamFee, uint256 buyAndBurnFee, uint256 referralFee);

    constructor(address mangoRouter,
        address mangoReferral,
        address token
        ) Ownable(msg.sender){
        mangoRouter = IMangoRouter(mangoRouter);
        mangoReferral = IMangoReferral(mangoReferral);
        mangoToken = IERC20(token);
    }

    function burn(uint256 amount) external onlyOwner{
        _buyMango(amount);
        //call the burn function in the erc20 token contract
    }
    //BUY MANGO IS NEEDED TO BUY AND BURN ,
    //ALSO TO BUY AND SEND MANGO TO REFERRAL
    function _buyMango(uint256 amount) private {

        //making a low level call to foward al gass fees
        (bool s) = address(mangoRouter).call{value:amount}(
            abi.encodeWithSignature("swap(address,address,uint256,address)",address(0),mangoToken,0,address(0))
        );
        if(!s) revert SwapFailed();
        // this values are in ether
        buyAndBurnFee -= amount;
        totalBurned += amount;
       // mangoRouter.swap{value:buyAndBurnFee}(address(0), address(mangoToken),0,address(0));
    }

    //of the amount comming in is the 3% fee wish is divided by 3 (1% each)
    function _setFees(uint256 amount) private {
        uint256 fee = (amount.mul(1000)).div(3).div(1000);
        teamFee = fee;
        buyAndBurnFee = fee;
        referralFee = fee;
        // // Final check
        //assert(teamFee + buyAndBurnFee + referralFee == amount);
    }
    function _receive(uint256 amount) private payable {
        totalFeesCollected += amount;
        _setFees(amount);
        emit FeesReceived(amount, teamFee, buyAndBurnFee, referralFee);
    }
    fallback() external payable {
        _receive(msg.value);
    }

}