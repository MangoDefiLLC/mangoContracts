// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenPresale is Ownable {
    IERC20 public token;
    uint256 public tokenPrice; // Price per token in ETH (1 ETH = X tokens)
    uint256 public totalRaised; // Total ETH raised
    uint256 public constant MAX_ETH = 300 ether; // Hard cap

    bool public saleActive = true;

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event SaleStatusUpdated(bool status);
    event Withdrawn(address indexed owner, uint256 amount);

    constructor(address _token, uint256 _tokenPrice) Ownable() {
        require(_token != address(0), "Invalid token address");
        token = IERC20(_token);
        tokenPrice = _tokenPrice;
    }

    // Buy tokens with ETH
    function buyTokens() external payable {
        require(saleActive, "Sale is not active");
        require(msg.value > 0, "Must send ETH");
        require(totalRaised + msg.value <= MAX_ETH, "Hard cap reached");

        uint256 tokensToReceive = msg.value * tokenPrice;
        require(token.balanceOf(address(this)) >= tokensToReceive, "Not enough tokens in contract");

        totalRaised += msg.value;
        token.transfer(msg.sender, tokensToReceive);

        emit TokensPurchased(msg.sender, msg.value, tokensToReceive);
    }

    // Change token price (only owner)
    function setTokenPrice(uint256 _newPrice) external onlyOwner {
        require(_newPrice > 0, "Price must be greater than zero");
        tokenPrice = _newPrice;
    }

    // Enable or disable the sale (only owner)
    function toggleSaleStatus() external onlyOwner {
        saleActive = !saleActive;
        emit SaleStatusUpdated(saleActive);
    }

    // Withdraw raised ETH (only owner)
    function withdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        payable(owner()).transfer(balance);
        emit Withdrawn(owner(), balance);
    }

    // Withdraw remaining tokens (only owner)
    function withdrawTokens() external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance > 0, "No tokens left");
        token.transfer(owner(), contractBalance);
    }

    // Allow contract to receive ETH
    receive() external payable {
        buyTokens();
    }
}