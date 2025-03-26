// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import{IRouterV2} from './interfaces/IRouterV2.sol';
import {IERC20} from './interfaces/IERC20.sol';

contract Presale {
    address public immutable owner;
    address public immutable mango;
    uint256 public immutable maxFunding = 337500000000000000000;

    IERC20 public immutable weth;
    IERC20 public immutable usdc;
    IRouterV2 public immutable routerV2;

    bool public presaleEnded;
    uint256 public tokensSold; // Track how many tokens are sold
    uint256 public FundTarget;
    uint256 public totalEthRaised;
    

   // Corrected prices in wei (1 ETH = $1800)
    uint256 public constant STAGE1_PRICE = 10_000_000_000 wei; // $0.000017 (7e9 wei)
    uint256 public constant STAGE2_PRICE = 15_000_000_000 wei; // $0.000019 (9e9 wei)
 

    // Adjusted stage limits
    uint256 public constant STAGE1_LIMIT = 13_500_000_000 * 10**18; // 13.5B tokens
    uint256 public constant STAGE2_LIMIT = 13_500_000_000 * 10**18; // 13.5B tokens
    

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event EthWithdrawn(address caller, uint256 amount);
    event Deposit(address sender, uint256 amount);

    constructor(address _token) {
        owner = msg.sender;
        routerV2 = IRouterV2(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        mango = _token;
        weth = IERC20(0x4200000000000000000000000000000000000006);//0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);//base weth 0x4200000000000000000000000000000000000006
        usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        presaleEnded = false;
    }

    function depositTokens(address token, uint256 amount) external {
        require(msg.sender == owner, 'Not owner');
        bool txS = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(txS, 'Transfer failed');
    }

    function buyTokens() public payable {
        require(!presaleEnded, "Presale ended");
        require(msg.value > 0, "Send ETH to buy tokens");

        totalEthRaised += msg.value;
        uint256 tokensToReceive = getAmountOutETH(msg.value);
        require(tokensToReceive > 0, "Try sending less ETH");
        tokensSold += tokensToReceive;
        
        require(IERC20(mango).transfer(msg.sender, tokensToReceive), "Token transfer failed");
        emit TokensPurchased(msg.sender, msg.value, tokensToReceive);
    }
    function getAmountOutUsdc(uint256 amountIn) public  returns (uint256 tokensBack){
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(weth);
        uint256[] memory amountOut = routerV2.getAmountsOut(amountIn,path);
        tokensBack = getAmountOutETH(amountOut[1]);
    }

    function getAmountOutETH(uint256 amount) public view returns (uint256 tokensToReceive) {
        if (totalEthRaised <= 135000000000000000000) {//if fund is less than 135 eth price1
            tokensToReceive = amount / STAGE1_PRICE;
        } else if (totalEthRaised <= 202500000000000000000) {//202.5
            tokensToReceive = amount / STAGE2_PRICE;
        }  else {
            tokensToReceive = 0;
        }
    }

    function withdrawETH() external returns (uint256 balance) {
        require(msg.sender == owner, 'Not owner');
        balance = address(this).balance;
        (bool success, ) = owner.call{value: balance}("");
        require(success, "ETH transfer failed");
        emit EthWithdrawn(msg.sender, balance);
    }

    function withdrawTokens(address _token) external returns (uint256 balance) {
        require(msg.sender == owner, 'Not owner');
        balance = IERC20(_token).balanceOf(address(this));
        bool s = IERC20(_token).transfer(owner, balance);
        require(s, "Token transfer failed");
    }

    function endPresale() external returns (bool) {
        require(msg.sender == owner, 'Not owner');
        presaleEnded = true;
        return true;
    }

    fallback() external payable {}
}