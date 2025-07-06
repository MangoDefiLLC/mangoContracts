// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
//import {IUniversalRouter} from './interfaces/IUniversalRouter.sol';

import {IRouterV2} from './interfaces/IRouterV2.sol';
import {IWETH9} from './interfaces/IWETH9.sol';
import {IERC20} from './interfaces/IERC20.sol';
import {IMangoReferral} from './interfaces/IMangoReferral.sol';
import {IUniswapV3Factory } from './interfaces/IUniswapV3Factory.sol';
import {IUniswapV2Factory } from './interfaces/IUniswapV2Factory.sol';
import {MangoReferral} from "./mangoReferral.sol";

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
contract MangoRouter002 {

    address public owner;
    IUniswapV2Factory public immutable factoryV2;
    IUniswapV3Factory public immutable factoryV3;
    IMangoReferral public  mangoReferral;
    ISwapRouter02 public immutable swapRouter02;
    IRouterV2 public immutable routerV2;
    IWETH9 public immutable weth;
    address public taxMan;
    uint256 public  referralFee;

    struct Path {
        address token0;
        address token1;
        uint256 amount;
        uint24 poolFee;// gas to be 0 to swap on v2
        address receiver;
        address referrer;
    }

    event Swap(address swaper,
        address token0, 
        address token1,
        uint amountOut);

    event ReferralPayout(uint256 amountToReferral);
   
    uint24[] public poolFees;
    uint24 public taxFee;

    event NewOwner(address newOner);
    constructor(){
        owner = msg.sender;
        // factoryV2 = IUniswapV2Factory(0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6);
        // factoryV3 = IUniswapV3Factory(0x33128a8fC17869897dcE68Ed026d694621f6FDfD);
        // routerV2 = IRouterV2(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        // swapRouter02 = ISwapRouter02(0x2626664c2603336E57B271c5C0b26F421741e481);
        // //ISwapRouter02(0x2626664c2603336E57B271c5C0b26F421741e481);
        // weth = IWETH9(0x4200000000000000000000000000000000000006);
        //sepolia
        factoryV2 = IUniswapV2Factory(0xF62c03E08ada871A0bEb309762E260a7a6a880E6);
        factoryV3 = IUniswapV3Factory(0x0227628f3F023bb0B980b67D528571c95c6DaC1c);
        routerV2 = IRouterV2(0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3);
        weth = IWETH9(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);// sepolia 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);
        swapRouter02 = ISwapRouter02(0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E);//ISwapRouter02(0x2626664c2603336E57B271c5C0b26F421741e481);
        //0x2626664c2603336E57B271c5C0b26F421741e481
        taxFee = 300;//%3 in basis points
        referralFee = 100;//1% in basis points
        poolFees = [10000,20000,2500,1000,100,3000,5000];
        taxMan = owner;
    }
    function changeTaxMan(address newTaxMan) external {
        require(msg.sender == owner,'not owner');
        taxMan = newTaxMan;
    }
    function _tax(uint256 _amount) private view returns(uint256 amount){
        uint256 taxAmount = _amount * taxFee / 10000;
        amount = _amount - taxAmount;//amount is the amount to user de rest is the fee
    }
     function _referalFee(uint256 amount) private view returns (uint256 referalPay){//this amount is the 3% for taxMan
        referalPay = (amount * referralFee + 9999) / 10000; 
    }
    function _payTaxMan(uint256 amount) private {
        (bool _s,) = taxMan.call{value:amount}("");
        if(_s != true) revert();
    }
    function _swap(Path memory data) private returns(uint256 amountOut){
       
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
            if(data.poolFee > 0){
                 weth.withdraw(amountOut);
            }
            //tax and pay taxman
            uint256 toUser = _tax(amountOut);
            (bool s,) = msg.sender.call{value:toUser}("");
            if(s != true) revert();

            if(data.referrer > address(0)){
                uint256 referalPay = _referalFee(toUser - amountOut);
                mangoReferral.distributeReferralRewards(msg.sender,referalPay,data.referrer);
                emit ReferralPayout(referalPay);
            }else{
                 _payTaxMan(amountOut - toUser);
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
    function swap(address token0, address token1,uint256 amount,address referrer) external payable returns(uint amountOut){
        if(msg.value == 0 && amount == 0) revert('both AMOUNTS cant be zero');
        if(msg.value > 0 && amount > 0) revert('both AMOUNTS cant be bigger than 0');
        if(token0 == address(0) && msg.value == 0) revert('token0 is address 0 , msg.value cant be 0');
        if(token1 == address(0) && amount == 0) revert('token1 is address zero, amount cant be zero');
        if(token0 == address(0) && token1 == address(0)) revert('both cant be address(0)');

        //CHECK IF SWAPPER IS A REFERRE
        //IF TRUE THEN TAKE THE 1% OF THE 3%
        //ELSE SWAP NORMALLY
    
        Path memory path;
        
        path.amount =  msg.value == 0 ? amount : _tax(msg.value);
        path.token0 = token0;
        path.token1 = token1;
        path.referrer =  referrer == address(0) ? mangoReferral.getReferralChain(msg.sender) : referrer;//if address 0 then user has no referrer
        address pair = factoryV2.getPair(
                token0 == address(0) ? address(weth):token0,
                token1 == address(0) ? address(weth) : token1
                );

        if(pair>address(0)){//v2 pool exist
            //IF AMOUNT IS 0, THEN IT WILL BE TAKEN AS ETH TO TOKEN
            //IF AMOUNT != 0 THEN IT WILL BE TAKEN AS IF TOKEN0 IS A ERC20 
            amountOut = _swap(path);
        }

        if(pair == address(0)){//find the v3 pool
             bool found;
            for(uint256 i = 0;i<poolFees.length;i++){
                address _pair = factoryV3.getPool(
                    token0  == address(0) ? address(weth):token0,
                    token1 == address(0) ? address(weth) : token1,
                    poolFees[i]
                );
                if(_pair > address(0)){
                    path.poolFee = poolFees[i];
                    found = true;
                    break;
                }
            }
            if(found){
                amountOut = _swap(path);
            } else {
                //ADD CHECK AERO AND PANCAKE
                revert("no V2 or V3 pool found");
            }
        }
        if(msg.value > 0){
            //IF TOKEN 0 IS ETH
            uint256 totalPayOut = msg.value - path.amount;
            if(path.referrer > address(0)){//user has a referer

                uint256 referralPay = _referalFee(totalPayOut);
                mangoReferral.distributeReferralRewards(msg.sender,referralPay,path.referrer);

                emit ReferralPayout(referralPay);
                _payTaxMan(totalPayOut);
                
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
        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
            .ExactInputSingleParams({
                tokenIn: data.token0, //token to swap
                tokenOut: data.token1, //token in return
                fee: data.poolFee,//poolFee
                recipient: data.receiver, //reciever of the output token
                amountIn: data.amount,// amont of input token you want to swap
                amountOutMinimum: 0, //set to zero in this case
                sqrtPriceLimitX96: 0 //set to zero
            });
            //call swap 
            if(msg.value > 0){
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
        if(msg.sender != owner) revert();
        owner = newOwner;
        emit NewOwner(newOwner);
    }
    function changeFee(uint24 newFee) public {
        require(msg.sender == owner);
        require(newFee<600);//less than 5%
        taxFee = newFee;
    }
    function setReferralContract(address referalAdd) external {
        require(msg.sender == owner);
        mangoReferral = IMangoReferral(referalAdd);
    }
    //function updateReferalContract()
    fallback() external payable{}
}
