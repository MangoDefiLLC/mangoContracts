// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMangoErrors} from './interfaces/IMangoErrors.sol';
interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}
    
contract MANGO_DEFI_TOKEN is ERC20, Ownable, ERC20Burnable {

    uint256 public buyTax = 200;  // 2% in basis points (BPS)
    uint256 public sellTax = 300; // 3% in basis points (BPS)
    address public uniswapRouterV2;
    address public taxWallet;

    mapping(address => bool) public isExcludedFromTax;
    mapping(address => bool) public isPair;

    event TaxesUpdated(uint256 buyTax, uint256 sellTax);
    event TaxWalletUpdated(address newTaxWallet);
    event PairAdded(address pair);
    event NewOwner(address newOwner);

    constructor(uint256 totalSupply) Ownable(msg.sender) ERC20("MANGO DEFI", "MANGO") {
     
        _mint(msg.sender, totalSupply);
    
        taxWallet = msg.sender;
        uniswapRouterV2 = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;//uniswap v2 router
        isExcludedFromTax[msg.sender] = true;
        isExcludedFromTax[address(this)] = true;
        isExcludedFromTax[uniswapRouterV2] = true;
    }
    //**THE TAXES FOR THIS IS DESIGNE FOR V2, V3 NEEDS TO BE ADDED AND TESTED */

    function addPair(address pair) external onlyOwner {
        require(pair != address(0), "Invalid pair address");
        isPair[pair] = true;
        emit PairAdded(pair);
    }

    function excludeAddress(address _addr) external onlyOwner returns (bool) {
        isExcludedFromTax[_addr] = true;
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        uint256 taxAmount = 0;

        if (!isExcludedFromTax[from] && !isExcludedFromTax[to]) {
            if (isPair[to]) {
                // Sell
                taxAmount = (amount*sellTax)/10000;
            } else if (isPair[from]) {
                // Buy
                taxAmount = (amount*buyTax)/10000;
            }
        }

        uint256 amountAfterTax = amount - taxAmount;
        super._transfer(from, to, amountAfterTax);

        if (taxAmount > 0) {
            super._transfer(from, taxWallet, taxAmount);
        }
    }
    function setTaxes(uint256 _buyTax, uint256 _sellTax) external {
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        require(_buyTax <= 300 && _sellTax <= 300, "Max tax is 3%");
        buyTax = _buyTax;
        sellTax = _sellTax;
        emit TaxesUpdated(_buyTax, _sellTax);
    }

    function setTaxWallet(address _taxWallet) external {
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        require(_taxWallet != address(0), "Zero address not allowed");
        taxWallet = _taxWallet;
        emit TaxWalletUpdated(_taxWallet);
    }

    function changeOwner(address _newOwner) external {
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        require(_newOwner != address(0), "Zero address not allowed");
        transferOwnership(_newOwner);
        emit NewOwner(_newOwner);
    }
}