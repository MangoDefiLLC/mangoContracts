// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
//import {IUniversalRouter} from './interfaces/IUniversalRouter.sol';
import{IERC20} from './interfaces/IERC20.sol';
import{IRouterV2} from './interfaces/IRouterV2.sol';
import {IUniswapV3Factory } from './interfaces/IUniswapV3Factory.sol';

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}

//@DEV this is the first version of the MAngo router
contract MangoRouter00 {

    address public owner;
    IUniswapV3Factory public immutable factoryV3;
    ISwapRouter02 public immutable swapRouter02;
    IRouterV2 public immutable routerV2;
    IERC20 public immutable weth;
    IERC20 public immutable usdc;
    uint24 public fee;

    event NewOwner(address newOner);

    constructor(){
        owner = msg.sender;
        factoryV3 = IUniswapV3Factory(0x33128a8fC17869897dcE68Ed026d694621f6FDfD);
        routerV2 = IRouterV2(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        weth = IERC20(0x4200000000000000000000000000000000000006);//0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);//base weth 0x4200000000000000000000000000000000000006
        usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        swapRouter02 = ISwapRouter02(0x2626664c2603336E57B271c5C0b26F421741e481);
        fee = 300;
    }
    function _tax(uint256 _amount) private view returns(uint256 amount){
        uint256 taxAmount = _amount * fee / 10000;
        amount = _amount - taxAmount;
    }
    function ethToTokensV3(address token, uint24 poolFee) external payable returns(uint256 result){
        if(poolFee == 0) revert();
        if(msg.value == 0) revert();
        uint256 amountIn = _tax(msg.value);
        //check this function
        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
            .ExactInputSingleParams({
                tokenIn: address(weth), //token to swap
                tokenOut: address(token), //token in return
                fee: poolFee,//poolFee
                recipient: msg.sender, //reciever of the output token
                amountIn: amountIn,// amont of input token you want to swap
                amountOutMinimum: 0, //set to zero in this case
                sqrtPriceLimitX96: 0 //set to zero
            });
            //call swap 
            result = swapRouter02.exactInputSingle{value:amountIn}(params);
    }
    //sell usdc for Weth in v3 pool
    function tokensForTokensV3(address token0, address token1, uint256 _amountToSell,uint24 _fee) public returns(uint256 result){
        if(_amountToSell == 0) revert();
        //tranfers token to this contract
        IERC20(token0).transferFrom(msg.sender,address(this),_amountToSell);
        uint256 _amountIn;
        token0 == address(usdc) ? 
            _amountIn = _tax(_amountToSell): 
            _amountIn = _amountToSell;
        bool s = IERC20(token0).approve(address(swapRouter02),_amountToSell);
        if(s != true) revert();
    
            ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
                .ExactInputSingleParams({
                    tokenIn: address(token0), //token to swap
                    tokenOut: address(token1), //token in return
                    fee: _fee,//poolFee
                    recipient: msg.sender, //reciever of the output token
                    amountIn: _amountIn,// amont of input token you want to swap
                    amountOutMinimum: 0, //set to zero in this case
                    sqrtPriceLimitX96: 0 //set to zero
                });
            //call swap 
            result = swapRouter02.exactInputSingle(params);
    }

    function ethToTokensV2(address token) payable public returns(uint[] memory amounts) {
        if(msg.value == 0) revert('value cant be zero');
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = token;
        uint256 amountIn = _tax(msg.value);//charge fee
        uint256[] memory amountOut = routerV2.getAmountsOut(amountIn,path);
        amounts = routerV2.swapExactETHForTokens{value:amountIn}(
            amountOut[1],//min amountOut
            path,
            msg.sender, //Recipient of the output tokens.
            block.timestamp + 200
        );
    }
    function tokensToEthV2(address token, uint256 amountIn) payable external returns(uint256 amountToPay) {
        if(amountIn == 0) revert();
        bool s = IERC20(token).transferFrom(msg.sender,address(this),amountIn);
        if(s != true) revert('token transfer failed');
        address[] memory path = new address[](2);
        path[1] = address(weth);
        path[0] = token;
        uint256[] memory amountOut = routerV2.getAmountsOut(amountIn,path);
        uint256[] memory amounts = routerV2.swapExactTokensForETH(
            amountIn,
            amountOut[1],
            path,
            address(this),
            block.timestamp + 200
            );
        amountToPay = _tax(amounts[1]);
        (bool _s,) = msg.sender.call{value:amountToPay}("");
        if(_s != true) revert();
    }
    function tokenToTokenV2_fee_usdc(address token0, address token1, uint256 _amountIn) external returns(uint256[] memory amounts) {
        if(_amountIn == 0) revert();
            //tranfer user tokens to contracat for swap
            IERC20(token0).transferFrom(msg.sender,address(this),_amountIn);
            IERC20(token0).approve(address(routerV2),_amountIn);
            address[] memory path = new address[](2);
            path[0] = token0;
            path[1] = token1;
            uint256 amountIn;
            token0 == address(usdc) ? amountIn = _tax(_amountIn) : amountIn = _amountIn; //if token in take fee
            uint256[] memory amountOut = routerV2.getAmountsOut(amountIn,path);
            uint deadline = block.timestamp + 100;
            amounts = routerV2.swapExactTokensForTokens(
                amountIn ,
                amountOut[1],
                path,
                msg.sender,
                deadline
            );
    }
    function withdrawEth()external returns(uint256 balance){
        if(msg.sender != owner) revert();
        balance = address(this).balance;
        (bool s,) = owner.call{value:balance}("");
        require(s);
    }
    function withdrawTokens(address token)external returns(uint256 balance){
        if(msg.sender != owner) revert();
        balance = IERC20(token).balanceOf(address(this));
        bool s = weth.transfer(owner,balance);
        if(s != true) revert();
    }
    function changeOwner(address newOwner) external {
        if(msg.sender != owner) revert();
        owner = newOwner;
        emit NewOwner(newOwner);
    }
    fallback() external payable{}

}
