// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import{IERC20} from './interfaces/IERC20.sol';
//import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";

/**
SUpply  */
contract Presale {
    address public immutable owner;
    address public immutable mango;

    uint256 public constant TOTAL_PRESALE_TOKENS = 60_000_000_000 * 10**18; // 60B tokens
    uint256 public tokensSold; //track how many token are sold
    //uint256 public constant MAX_ETH = 320 ether;
    uint256 public totalEthRaised;

    uint256 public constant STAGE1_PRICE = 0.0000000054 ether; // phase 1 price $0.000014
    uint256 public constant STAGE2_PRICE = 0.000000008 ether; // phase 2 price  $0.000018
    uint256 public constant STAGE3_PRICE = 0.0000000085 ether; // phase 2 price  $0.000019
    //stage 2 price is even with launch
    //usdc price
    // uint256 public constant USDC_STAGE1_PRICE = 0.000014;
    // uint256 public constant USDC_STAGE2_PRICE = 0.00002;
    // uint256 public constant USDC_STAGE3_PRICE = 0.000023;
    //target price when uniswap launch $0.000018 around 0.0000000067 ether

    uint256 public constant STAGE1_LIMIT = 13_500_000_000 * 10**18; // 13.5B tokens
    uint256 public constant STAGE2_LIMIT = 6_750_000_000 * 10**18; // 6.75 tokens
    uint256 public constant STAGE3_LIMIT = 6_750_000_000 * 10**18; // 6.75 tokens

    bool public presaleEnded = false;

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event EthWithdrawn(address caller,uint256 amount);
    event Deposit(address sender,uint256 amount);

    constructor(address _token) {
        owner = msg.sender;
        mango = _token;
    }

    function depositTokens(address token) external {
        require(msg.sender == owner,'not owner');
        bool txS = IERC20(token).transferFrom(msg.sender,address(this),TOTAL_PRESALE_TOKENS);
        require(txS,'tranfer failed');
        emit Deposit(msg.sender,TOTAL_PRESALE_TOKENS);
    }
    function buy_token_with_usdc(address _usdc,uint256 _amount)external returns(uint256 amount){
        require(_amount!=0,'amount cant be zero');
        bool s = IERC20(_usdc).transferFrom(msg.sender,address(this),_amount);
        require(s);
        //get amount out
        
    }
    function buyTokens()public payable {
        require(!presaleEnded, "Presale ended");
        require(msg.value > 0, "Send ETH to buy tokens");
        
        uint256 tokensToReceive = this.getAmountOutETH(msg.value);//function to get tokens out
        require(tokensToReceive != 0,"try sending less eth");
        tokensSold += tokensToReceive;
        totalEthRaised += msg.value;

        require(IERC20(mango).transfer(msg.sender, tokensToReceive), "Token transfer failed");
        emit TokensPurchased(msg.sender, msg.value, tokensToReceive);
    }
    function getAmountOutETH(uint256 amount) public view returns(uint256 tokensToReceive){
        //to get the expected amount out for the swap
         if (tokensSold < STAGE1_LIMIT) {
            tokensToReceive = amount / STAGE1_PRICE;
        } else if (tokensSold < (STAGE1_LIMIT + STAGE2_LIMIT)){
            tokensToReceive = amount / STAGE2_PRICE;
        }else if (tokensSold < (STAGE1_LIMIT + STAGE2_LIMIT + STAGE3_LIMIT)){
            tokensToReceive = amount / STAGE3_PRICE;
        } else {
            //if this returns 0 then user needs to send less tokens
            tokensToReceive = 0;
        }
    }/**
    function getAmountOutUSDC(uint256 amount) public view returns(uint256 tokensToReceive){
         //to get the expected amount out for the swap
         if (tokensSold < STAGE1_LIMIT) {
            tokensToReceive = amount / USDC_STAGE1_PRICE;
        } else if (tokensSold < STAGE2_LIMIT){
            tokensToReceive = amount / USDC_STAGE2_PRICE;
        }else if(tokensSold < STAGE3_LIMIT){
            tokensToReceive = amount / USDC_STAGE3_PRICE;

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
            tokensToReceive = amount / USDC_STAGE2_PRICE;
        }else if(tokensSold < STAGE3_LIMIT){
            tokensToReceive = amount / USDC_STAGE3_PRICE;

        } else {
            //if this returns 0 then user needs to send less tokens
            tokensToReceive = 0;
        }
    }
     */
    function withdrawETH() external returns (uint256 balance) {
        require(msg.sender == owner,'not owner');
        (bool success, ) = owner.call{value: totalEthRaised}("");
        require(success, "ETH transfer failed");
        emit EthWithdrawn(msg.sender,totalEthRaised); // Emit an event for transparency
    }
    function withdrawTokens(address _token)external returns(uint256 balance){
            if(msg.sender != owner) revert('not owner');
            balance = IERC20(_token).balanceOf(address(this));
            bool s = IERC20(_token).transfer(owner,balance);
            if(s != true) revert();
        }
    function endPresale() external returns(bool){
        require(msg.sender == owner);
        presaleEnded = true;
        return true;
    }

    fallback() external payable{}
}
