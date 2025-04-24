// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
//import {IUniversalRouter} from './interfaces/IUniversalRouter.sol';
import{IERC20} from './interfaces/IERC20.sol';
import{IRouterV2} from './interfaces/IRouterV2.sol';
import{IWETH9} from './interfaces/IWETH9.sol';
import {IUniswapV3Factory } from './interfaces/IUniswapV3Factory.sol';
import {IUniswapV2Factory } from './interfaces/IUniswapV2Factory.sol';
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
contract MangoRouter001 {

    address public owner;
    IUniswapV2Factory public immutable factoryV2;
    IUniswapV3Factory public immutable factoryV3;
    ISwapRouter02 public immutable swapRouter02;
    IRouterV2 public immutable routerV2;
    IWETH9 public immutable weth;
    address public taxMan;
   
    uint24[] public poolFees;
    uint24 public taxFee;
    struct Path {
        address poolAddress;
        uint24 poolFee;
    }

    event NewOwner(address newOner);
    constructor(){
        owner = msg.sender;
        factoryV2 = IUniswapV2Factory(0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6);
        factoryV3 = IUniswapV3Factory(0x33128a8fC17869897dcE68Ed026d694621f6FDfD);
        routerV2 = IRouterV2(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        weth = IWETH9(0x4200000000000000000000000000000000000006);
        swapRouter02 = ISwapRouter02(0x2626664c2603336E57B271c5C0b26F421741e481);
        taxFee = 300;
        poolFees = [10000,3000,5000];
        taxMan = owner;
    }
    function changeTaxMan(address newTaxMan) external {
        require(msg.sender == owner,'not owner');
        taxMan = newTaxMan;
    }
    function _tax(uint256 _amount) private view returns(uint256 amount){
        uint256 taxAmount = _amount * taxFee / 10000;
        amount = _amount - taxAmount;
    }
    function _payTaxMan(uint256 amount) private {
        (bool _s,) = taxMan.call{value:amount}("");
        if(_s != true) revert();
    }
    function swap(address token0, address token1,uint256 amount) external payable returns(uint amountOut){
        if(msg.value == 0 && amount == 0) revert('both cant be zero');
        if(token0 == address(0) && msg.value != 0){
            //swapping eth for token
            //amount has to be 0
            //token0 has to be 0 address
            Path memory data = findPath(address(weth),token1);
            //if fee is 0 then call v2
            //eth is token 0 i take fee in eth
            //collect fee the swap
            uint toSwap = _tax(msg.value);
            uint256 toTaxMan = msg.value - toSwap;
            _payTaxMan(toTaxMan);
            if(data.poolFee == 0){
                
                amountOut = _ethToTokensV2(token1,toSwap);
            }else{
                amountOut = ethToTokensV3(token1,data.poolFee);
            }

        }else if(token0 != address(0) && token1 == address(0) && amount != 0){
            //swapping token to eth
            Path memory data = findPath(token0,address(weth));
            if(data.poolFee == 0){
                //eth is token 0 i take fee in eth
                //collect fee the swap
                amountOut = tokensToEthV2(token0,amount);
                uint tax = _tax(amountOut);
                uint256 toTaxMan = amountOut - tax;
                _payTaxMan(toTaxMan);
            }

        }
    }
    function ethToTokensV3(address token, uint24 poolFee) public payable returns(uint256 result){
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
    function findPath(address token0,address token1) public returns(Path memory){
        //check v2 pair
        /**
            NOTE
            ADD STRUCT TO RETURN ADDRESS OF POOL
            IF V3 SWAP ADD FEE, ELSE UST SLOT IT WITH 0 */
        Path memory path;
        address pair = factoryV2.getPair(token0,token1);
        if(pair == address(0)){
            for(uint256 i = 0;i<poolFees.length;i++){
                address _pair = factoryV3.getPool(
                    token0,
                    token1,
                    poolFees[i]
                );
                if(_pair != address(0)){
                    
                    return Path(_pair,poolFees[i]);
                }
            }

        }else{
            return Path(pair,0);
        }
    }
    //sell usdc for Weth in v3 pool
    function tokensForTokensV3(address token0, address token1, uint256 amountToSell,uint24 _fee) public returns(uint256 result){
        if(amountToSell == 0) revert();
        //tranfers token to this contract
        IERC20(token0).transferFrom(msg.sender,address(this),amountToSell);
        bool s = IERC20(token0).approve(address(swapRouter02),amountToSell);
        if(s != true) revert();
    
            ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
                .ExactInputSingleParams({
                    tokenIn: address(token0), //token to swap
                    tokenOut: address(token1), //token in return
                    fee: _fee,//poolFee
                    recipient: msg.sender, //reciever of the output token
                    amountIn: amountToSell,// amont of input token you want to swap
                    amountOutMinimum: 0, //set to zero in this case
                    sqrtPriceLimitX96: 0 //set to zero
                });
            //call swap 
            result = swapRouter02.exactInputSingle(params);
    }
     //sell usdc for Weth in v3 pool
    function tokensForEthV3(address token0, uint256 amountToSell,uint24 _fee) public returns(uint256 amountOut){
        if(amountToSell == 0) revert();
        //tranfers token to this contract
        IERC20(token0).transferFrom(msg.sender,address(this),amountToSell);
        uint256 _amountIn;
       
        bool s = IERC20(token0).approve(address(swapRouter02),amountToSell);
        if(s != true) revert();
    
            ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
                .ExactInputSingleParams({
                    tokenIn: address(token0), //token to swap
                    tokenOut: address(weth), //token in return
                    fee: _fee,//poolFee
                    recipient:address(this), //reciever of the output token
                    amountIn: amountToSell,// amont of input token you want to swap
                    amountOutMinimum: 0, //set to zero in this case
                    sqrtPriceLimitX96: 0 //set to zero
                });
            //call swap 
            amountOut = swapRouter02.exactInputSingle(params);
            //unwrap eth
            if(weth.transfer(msg.sender,amountOut) != true) revert('weth unwrapping failed');
    }
    //DEV
    //this is a modifies version of the swapv2 
    //to collect eth on the way in on swap function
    
    function _ethToTokensV2(address token,uint256 amountIn) private returns(uint) {
        if(msg.value == 0) revert('value cant be zero');
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
    function tokensToEthV2(address token, uint256 amountIn) public returns(uint256) {
        if(amountIn == 0) revert();
        bool s = IERC20(token).transferFrom(msg.sender,address(this),amountIn);
        bool sucs = IERC20(token).approve(address(routerV2),amountIn);
        //if(s != true || sucs != true) revert('token transfer failed');
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
        return amounts[1];
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
    function changeFee(uint24 newFee) public returns (bool){
        require(msg.sender == owner);
        require(newFee<600);//less than 5%
        taxFee = newFee;
    }
    fallback() external payable{}

}
