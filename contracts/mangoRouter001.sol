// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
//import {IUniversalRouter} from './interfaces/IUniversalRouter.sol';

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import { IUniswapV2Factory } from "./interfaces/IUniswapV2Factory.sol";
import { IUniswapV3Factory } from "./interfaces/IUniswapV3Factory.sol";
import { IRouterV2 } from "./interfaces/IRouterV2.sol";
import { IMangoReferral } from "./interfaces/IMangoReferral.sol";
import { IWETH9 } from "./interfaces/IWETH9.sol";
import { IMangoErrors } from "./interfaces/IMangoErrors.sol";
import {IMangoStructs} from "./interfaces/IMangoStructs.sol";
interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}


contract MangoRouter002 is ReentrancyGuard, Ownable {

    IUniswapV2Factory public immutable factoryV2;
    IUniswapV3Factory public immutable factoryV3;
    IMangoReferral public  mangoReferral;
    ISwapRouter02 public immutable swapRouter02;

    IRouterV2 public immutable routerV2;
    IWETH9 public immutable weth;
    address public taxMan; //receiver of the tax
    uint256 public  referralFee;
    uint256 public immutable BASIS_POINTS =  10000;

    struct Path {
        address token0;
        address token1;
        uint256 amount;
        uint24 poolFee;// gas to be 0 to swap on v2
        address receiver;
        address referrer;
    }

    event Swap(
        address swaper,
        address token0, 
        address token1,
        uint amountOut
        );
    event Amount(uint256,uint256);
    event Address(address);

    event ReferralPayout(uint256 amountToReferral);
    event payTaxMan(uint256 amountToTaxMan);
   
    uint256[] public poolFees;
    uint256 public taxFee;

    event NewOwner(address newOner);
   
    constructor(IMangoStructs.cParamsRouter memory cParams) Ownable() {
        //owner = msg.sender;
        factoryV2 = IUniswapV2Factory(cParams.factoryV2);
        factoryV3 = IUniswapV3Factory(cParams.factoryV3);
        routerV2 =  IRouterV2(cParams.routerV2);
        swapRouter02 = ISwapRouter02(cParams.swapRouter02);//
        //ISwapRouter02(0x2626664c2603336E57B271c5C0b26F421741e481);
        weth = IWETH9(cParams.weth);
        taxFee = cParams.taxFee;//%3 in basis points
        referralFee = cParams.referralFee;//1% in basis points

        //I WIll like to see how to make better the search of the pool
        //or jut route to a msart router
        poolFees = [100,1000,BASIS_POINTS,20000,2500,taxFee,3000,5000];
        taxMan = msg.sender;//taxman is set to msg.sender until changed
        //ideally you want taxman to the the manager SMC
    }
    function changeTaxMan(address newTaxMan) external {
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        taxMan = newTaxMan;
    }
    function _transferEth(address receiver,uint256 amount) internal{
        (bool s,) = receiver.call{value:amount}("");
        if(s != true) revert IMangoErrors.TransferFailed();
    }
    function _tax(uint256 _amount) private view returns(uint256 amount){
        uint256 taxAmount = (_amount * taxFee)/BASIS_POINTS;
        amount = _amount - taxAmount;//amount is the amount to user de rest is the fee
    }
     function _referalFee(uint256 amount) private view returns (uint256 referalPay){//this amount is the 3% for taxMan
        referalPay = (amount*referralFee)/BASIS_POINTS; 
    }
    function _payTaxMan(uint256 amount) private {
        _transferEth(taxMan,amount);
        emit payTaxMan(amount);
    }
    function _swap(Path memory data) private returns(uint256 amountOut){
        uint256  amountToUser;
        if(data.token0 == address(0)){//eth to token 
            //swapping eth to token
            data.token0 = address(weth);
            data.receiver = msg.sender;
            amountOut = data.poolFee == 0 ? _ethToTokensV2(data.token1,data.amount) : tokensToTokensV3(data);
           
            emit Swap(msg.sender,data.token0,data.token1,amountOut);

        }else if(data.token1 == address(0)){//token to eth 
    
            data.token1 = address(weth);
            data.amount = data.amount;
            data.receiver = address(this);
            amountOut = data.poolFee == 0 ? _tokensToEthV2(data) : tokensToTokensV3(data);

            emit Swap(msg.sender,data.token0,data.token1,amountOut);

            //UNWRAP ETH AFTER TOKPEN TO TOKEN SWAP
            //only when v3 pool
            emit Amount(amountOut,IERC20(address(weth)).balanceOf(address(this)));
            if(data.poolFee > 0){
                //unswarpp amount
                  (bool success, ) = address(weth).call(
                    abi.encodeWithSignature("withdraw(uint256)", amountOut)
                );
                if(!success) revert IMangoErrors.EthUnwrapFailed();
                //get amount to user after tax
                amountToUser = _tax(amountOut);// amount to user after tax

                //pay user its funds
                _transferEth(msg.sender,amountToUser);
                
                //ones user is paid check if user has referral
                if(data.referrer > address(0)){
                    uint256 referalPay = _referalFee(amountOut-amountToUser);//pass 3%
                    //call distribute rewards on mango referral
                    bool s = _distributeReferralRewards(msg.sender,referalPay,data.referrer);
                    if(!s) revert IMangoErrors.CallDistributeFailed();

                    emit ReferralPayout(referalPay);
                    //pay tax man
                    uint256 taxManPay = (amountOut-amountToUser)-referalPay;
                    _payTaxMan(taxManPay);
                }else{
                    _payTaxMan(amountOut-amountToUser);
                }

            }else{
                 _transferEth(msg.sender,amountToUser);
                _payTaxMan(amountOut - amountToUser);
            
            }
        }else if(data.token0 > address(0) && data.token1 > address(0)){//token to token
            //ADD TAX TO TOKENS TO TOKEN TRANSACTIONS
            data.receiver = msg.sender;
            amountOut = data.poolFee == 0 ? tokensToTokensV2(data) : tokensToTokensV3(data);
            emit Swap(msg.sender,data.token0,data.token1,amountOut);

        }else{
            revert('uncharted terrain');
        }
    }
    function tokensToTokensV2(Path memory data)public returns(uint256){
        require(IERC20(data.token0).transferFrom(msg.sender,address(this),data.amount));
        require(IERC20(data.token0).approve(address(routerV2),data.amount));
         address[] memory path = new address[](2);
        path[0] = data.token0;
        path[1] = data.token1;
        uint256[] memory amountsOut = routerV2.getAmountsOut(data.amount,path);
        //swap
        uint256[] memory amount = routerV2.swapExactTokensForTokens(
            data.amount,
            amountsOut[1],
            path,
            data.receiver,
            block.timestamp*200
        );
        return amount[1];
    }
    function _distributeReferralRewards(
        address user,
        uint256 amount,
        address referrer
    ) internal returns (bool) {
        (bool s, ) = address(mangoReferral).call( 
            abi.encodeWithSignature("distributeReferralRewards(address,uint256,address)",
            user,
            amount,
            referrer));
        return s;
    }
    function swap(address token0, address token1,uint256 amount,address referrer) external payable returns(uint amountOut){
        if(msg.value == 0 && amount == 0) revert IMangoErrors.BothCantBeZero();
        if(msg.value > 0 && amount > 0) revert IMangoErrors.BothCantBeZero();
         //if swapping eth msg.value cant be zero
        if(token0 == address(0) && msg.value == 0) revert IMangoErrors.ValueIsZero();
        //when swapping tokens the amount param cant be 0
        if(token1 == address(0) && amount == 0) revert IMangoErrors.ValueIsZero();
        //both tokens cant be 0
        if(token0 == address(0) && token1 == address(0)) revert IMangoErrors.BothCantBeZero();
    
        Path memory path;
        
        path.amount =  msg.value == 0 ? amount : _tax(msg.value);//only tax eth to token
        path.token0 = token0;
        path.token1 = token1;
        //@dev this line is for cheking if swapper has been referr
       // path.referrer =  referrer == address(0) ? mangoReferral.getReferralChain(msg.sender) : referrer;//if address 0 then user has no referrer
        path.referrer = referrer;//by default referrer is address 0 
            //find the v3 pool
             bool found;
             address pair;
            for(uint256 i = 0;i<poolFees.length;i++){
                pair = factoryV3.getPool(
                    token0  == address(0) ? address(weth):token0,
                    token1 == address(0) ? address(weth) : token1,
                    uint24(poolFees[i])//uniswap get a uint24 and my array has uint256 so i need to cast it
                );
                if(pair > address(0)){
                    path.poolFee = uint24(poolFees[i]);
                    found = true;
                    break;
                }
            }
            if(found){
                amountOut = _swap(path);
            } else {
                // //ADD CHECK AERO AND PANCAKE
                // revert("no V2 or V3 pool found"); 
                pair = factoryV2.getPair(
                token0 == address(0) ? address(weth):token0,
                token1 == address(0) ? address(weth) : token1
                );

                if(pair>address(0)){//v2 pool exist
                    //IF AMOUNT IS 0, THEN IT WILL BE TAKEN AS ETH TO TOKEN
                    //IF AMOUNT != 0 THEN IT WILL BE TAKEN AS IF TOKEN0 IS A ERC20 
                    amountOut = _swap(path);
                }else{
                    revert('no path found');
                }
                
            }
        if(msg.value > 0){
            uint256 totalPayOut = msg.value - path.amount;//this amount is already taxed
            //TOTAL PAYOUT IS CURERNTLYU THE 3%
            if(path.referrer > address(0)){//user has a referer

                uint256 referralPay = _referalFee(totalPayOut);//GET THE 1% FOR THE REFERRAL
                //E: THIS SNIPPET IS ONLU FOR NONE BASE

                //call distribute rewards on mango referral
                bool s = _distributeReferralRewards( 
                    msg.sender,//user
                    referralPay,//amount to pay
                    path.referrer//address of referrer
                    );
                if(!s) revert IMangoErrors.CallDistributeFailed();
                

                emit ReferralPayout(referralPay);
                _payTaxMan(totalPayOut-referralPay);

            }else{
                _payTaxMan(totalPayOut);
            }
                
         }
    }
    
    function tokensToTokensV3(Path memory data) public payable returns(uint256 result){
        if(msg.value == 0){
            require(IERC20(data.token0).approve(address(swapRouter02),data.amount),'approve failed');
            require(IERC20(data.token0).transferFrom(msg.sender,address(this),data.amount), 'tranfer failed');
        }      
        //check this function
        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02.ExactInputSingleParams({
                tokenIn: data.token0, //token to swap
                tokenOut: data.token1, //token in return
                fee: data.poolFee,//poolFee
                recipient: data.receiver, //reciever of the output token
                deadline: block.timestamp + 2,
                amountIn: data.amount,// amont of input token you want to swap
                amountOutMinimum: 0, //set to zero in this case
                sqrtPriceLimitX96: 0 //set to zero
            });
            //call swap 
            if(msg.value > 0){
                emit Address(address(swapRouter02));
                //change it to low level
                // (bool s,) = address(swapRouter02).call(abi.encodeWithSignature('exactInputSingle',params));
                // if(!s) revert IMangoErrors.SwapFailed();
                result = swapRouter02.exactInputSingle{value:data.amount}(params);
            }else{
                result = swapRouter02.exactInputSingle(params);
            }
    }
     //sell usdc for Weth in v3 pool
    //DEV
    //this is a modifies version of the swapv2 
    //to collect eth on the way in on swap function
    
    function _ethToTokensV2(address token,uint256 amountIn) private returns(uint) {
        
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = token;
        uint256[] memory amountOut = routerV2.getAmountsOut(amountIn,path);
        uint[] memory amounts = routerV2.swapExactETHForTokens{value:amountIn}(
            amountOut[1],//min amountOut
            path,
            msg.sender, //Recipient of the output tokens.
            block.timestamp + 200
        );
        return amounts[1];//amount out of the swap
    }
   
    function _tokensToEthV2(Path memory data) private returns(uint256) {
        require(IERC20(data.token0).transferFrom(msg.sender,address(this),data.amount),'TF Failed!');
        require(IERC20(data.token0).approve(address(routerV2),data.amount),'AP Failed!');
        //if(s != true || sucs != true) revert('token transfer failed');
        address[] memory path = new address[](2);
        path[1] = data.token1;
        path[0] = data.token0;
        uint256[] memory amountOut = routerV2.getAmountsOut(data.amount,path);
        uint256[] memory amounts = routerV2.swapExactTokensForETH(
            data.amount,
            amountOut[1],
            path,
            data.receiver,
            block.timestamp + 200
            );
        return amounts[1];
    }

    function changeOwner(address newOwner) external {
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        _transferOwnership(newOwner);
        emit NewOwner(newOwner);
    }
    function setReferralContract(address referalAdd) external {
       if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        mangoReferral = IMangoReferral(referalAdd);
    }
    function withdrawEth() external{
        if(msg.sender !=  owner()) revert IMangoErrors.NotOwner();
        _transferEth(msg.sender,address(this).balance);
    }
    //THIS FUNCTION IS TO RESCUE TOKENS SENT BY MISTAKE TO THE CONTRACT
    //ONLY OWNER CAN CALL THIS FUNCTION
    function withdrawToken(address token) external {
       if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        uint256 amount = IERC20(token).balanceOf(address(this));
        require(IERC20(token).transfer(msg.sender,amount));
    }
    fallback()external payable{
    }
}
