// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from './interfaces/IERC20.sol';

contract Presale {
    address public immutable owner;
    address public immutable mango;

    uint256 public constant TOTAL_PRESALE_TOKENS = 60_000_000_000 * 10**18; // 60B tokens
    uint256 public tokensSold; // Track how many tokens are sold
    uint256 public constant MAX_ETH = 250 ether; // ~500k USD at 1 ETH = $2000
    uint256 public totalEthRaised;

    // Corrected prices in wei (1 ETH = $2000)
    uint256 public constant STAGE1_PRICE = 7_000_000_000 wei; // $0.000014 (7e9 wei)
    uint256 public constant STAGE2_PRICE = 9_000_000_000 wei; // $0.000018 (9e9 wei)
    uint256 public constant STAGE3_PRICE = 9_500_000_000 wei; // $0.000019 (9.5e9 wei)

    // Adjusted stage limits
    uint256 public constant STAGE1_LIMIT = 13_500_000_000 * 10**18; // 13.5B tokens
    uint256 public constant STAGE2_LIMIT = 6_750_000_000 * 10**18; // 6.75B tokens
    uint256 public constant STAGE3_LIMIT = 6_750_000_000 * 10**18; // 6.75B tokens

    bool public presaleEnded = false;

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event EthWithdrawn(address caller, uint256 amount);
    event Deposit(address sender, uint256 amount);

    constructor(address _token) {
        owner = msg.sender;
        mango = _token;
    }

    function depositTokens(address token) external {
        require(msg.sender == owner, 'Not owner');
        bool txS = IERC20(token).transferFrom(msg.sender, address(this), TOTAL_PRESALE_TOKENS);
        require(txS, 'Transfer failed');
        emit Deposit(msg.sender, TOTAL_PRESALE_TOKENS);
    }

    function buyTokens() public payable {
        require(!presaleEnded, "Presale ended");
        require(msg.value > 0, "Send ETH to buy tokens");
        require(totalEthRaised + msg.value <= MAX_ETH, "Exceeds max ETH limit");

        uint256 tokensToReceive = getAmountOutETH(msg.value);
        require(tokensToReceive != 0, "Try sending less ETH");

        tokensSold += tokensToReceive;
        totalEthRaised += msg.value;

        require(IERC20(mango).transfer(msg.sender, tokensToReceive), "Token transfer failed");
        emit TokensPurchased(msg.sender, msg.value, tokensToReceive);
    }

    function getAmountOutETH(uint256 amount) public view returns (uint256 tokensToReceive) {
        if (tokensSold < STAGE1_LIMIT) {
            tokensToReceive = amount / STAGE1_PRICE;
        } else if (tokensSold < STAGE1_LIMIT + STAGE2_LIMIT) {
            tokensToReceive = amount / STAGE2_PRICE;
        } else if (tokensSold < STAGE1_LIMIT + STAGE2_LIMIT + STAGE3_LIMIT) {
            tokensToReceive = amount / STAGE3_PRICE;
        } else {
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