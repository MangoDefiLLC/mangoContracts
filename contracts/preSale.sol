// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import{IERC20} from './interfaces/IERC20.sol';
//import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";

/**
SUpply  */
contract Presale is Ownable {
    address public immutable owner;
    address public immutable token;

    uint256 public constant TOTAL_PRESALE_TOKENS; // 60B tokens
    uint256 public tokensSold; //track how many token are sold
    //uint256 public constant MAX_ETH = 320 ether;
    uint256 public totalEthRaised;

    uint256 public constant STAGE1_PRICE = 0.0000000054 ether; // phase 1 price $0.000014
    uint256 public constant STAGE2_PRICE = 0.0000000068 ether; // phase 2 price  $0.000018
    //stage 2 price is even with launch
    //usdc price
    uint256 public constant USDC_STAGE1_PRICE = 0.000014;
    uint256 public constant USDC_STAGE2_PRICE = 0.000019;
    //target price when uniswap launch $0.000018 around 0.0000000067 ether

    uint256 public constant STAGE1_LIMIT = 13_500_000_000 * 10**18; // 13.5B tokens
    uint256 public constant STAGE2_LIMIT = 13_500_000_000 * 10**18; // 13.5B tokens

    bool public presaleEnded = false;

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event EthWithdrawn(uint256 amount);
    event Deposit(address sender,uint256 amount);

    constructor(address _token) {
        owner = msg.sender;
        token = _token;
    }

    function mangoDeposit(uint256 tokenAmount,address token) external {
        require(msg.sender != owner);
        if(TOTAL_PRESALE_TOKENS  >= 60_000_000_000 * 10**18 )revert('60 Billion cap on pre sale');
        TOTAL_PRESALE_TOKENS += tokenAmount;
        bool txS = IERC20(token).transferFrom(msg.sender,tokenAmount);
        require(txS);
        emit Desposit(msg.sender,tokenAmount);
    }
    function buy_token_with_usdc(address _usdc,uint256 amount)external returns(uint256 amount){
        require(amount!=0,'amount cant be zero');


    }
    function buyTokens()public payable {
        require(!presaleEnded, "Presale ended");
        require(msg.value > 0, "Send ETH to buy tokens");
        
        uint256 tokensToReceive = getAmountOut(msg.value);//function to get tokens out
        require(tokensToReceive != 0,"try sending less eth");
        tokensSold += tokensToReceive;
        totalEthRaised += msg.value;

        require(token.transfer(msg.sender, tokensToReceive), "Token transfer failed");
        emit TokensPurchased(msg.sender, msg.value, tokensToReceive);
    }
    function getAmountOutETH(uint256 amount) public view returns(uint256 tokensToReceive){
        //to get the expected amount out for the swap
         if (tokensSold < STAGE1_LIMIT) {
            tokensToReceive = amount / STAGE1_PRICE;
        } else if (tokensSold < STAGE2_LIMIT){
            tokensToReceive = amount / STAGE2_PRICE;
        } else {
            //if this returns 0 then user needs to send less tokens
            tokensToReceive = 0;
        }
    }
     function getAmountOutUSDC(uint256 amount) public view returns(uint256 tokensToReceive){
         //to get the expected amount out for the swap
         if (tokensSold < STAGE1_LIMIT) {
            tokensToReceive = amount / USDC_STAGE1_PRICE;
        } else if (tokensSold < STAGE2_LIMIT){
            tokensToReceive = amount / USDC_STAGE2_PRICE ;
        } else {
            //if this returns 0 then user needs to send less tokens
            tokensToReceive = 0;
        }
    }
    function withdrawEth() external returns (uint256 balance) {
        require(msg.sender == owner);
        balance = address(this).balance;
        (bool success, ) = owner().call{value: balance}("");
        require(success, "ETH transfer failed");
        emit EthWithdrawn(msg.sender,balance); // Emit an event for transparency
    }
    //DEV: remember approving the contract before depositing
    function depositTokens(uint256 amount,address token) external {
        require(msg.sender == owner);
        bool s = IERC20(token).transferFrom(msg.sender,amount);
        require(s);
        emit Deposit(amount);
    }
    function withdrawTokens(address _token)external returns(uint256 balance){
            if(msg.sender != owner) revert();
            balance = IERC20(token).balanceOf(address(this));
            bool s = weth.transfer(owner,balance);
            if(s != true) revert();
        }

    fallback() external payable{}
}
