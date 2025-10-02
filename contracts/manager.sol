// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {IMangoRouter} from '../contracts/interfaces/IMangoRouter.sol';
import {MANGO_DEFI_TOKEN} from '../contracts/mangoToken.sol';
import {IMangoReferral} from '../contracts/interfaces/IMangoReferral.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**THIS MODULE IS MENT TO MANAGE FEES FROM MANGO ROUTER AND TOKENS TAX
FUNCTIONS:
* BUY AND BURN - BUY X AMOUNT OF THE HOLDING AND BURN
* SEND X AMOUNT OF HOLDING TO OWNER
* TRACK TOKEN TAXES */
contract Mango_Manager is Ownable{
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

    error NotOwner();
    error SwapFailed();

    event FeesReceived(uint256 totalAmount);

    constructor(
        address _mangoRouter,
        address _mangoReferral,
        address _token
        ) Ownable(){
        mangoRouter = IMangoRouter(_mangoRouter);
        mangoReferral = IMangoReferral(_mangoReferral);
        mangoToken = IERC20(_token);
    }

    function burn(uint256 amount) external onlyOwner{
        if(amount > buyAndBurnFee) revert();
        _buyMango(amount);
        //call the burn function in the erc20 token contract
        mangoToken.burn(amount);
        //this are calculated in eth
        buyAndBurnFee -= amount;
        totalBurned += amount;
    }
    //BUY MANGO IS NEEDED TO BUY AND BURN ,
    //ALSO TO BUY AND SEND MANGO TO REFERRAL
    //NOTE THE BUY MANGO SUBS TO THE BUY AND BUT AMOUN
    // WHAT IF IM BUYING TO REFERRAL,?
    function _buyMango(uint256 amount) private returns(uint256){
        //making a low level call to foward al gass fees
        (bool s,) = address(mangoRouter).call{value:amount}(
            abi.encodeWithSignature("swap(address,address,uint256,address)",address(0),address(mangoToken),0,address(0))
        );
        if(!s) revert SwapFailed();
    }

    //of the amount comming in is the 3% fee wish is divided by 3 (1% each)
    function _setFees(uint256 amount) private {
        uint256 fee = (amount*10000) / 3 / 10000;
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
}