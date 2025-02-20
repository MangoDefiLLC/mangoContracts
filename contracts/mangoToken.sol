// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

contract MANGO_DEFI is ERC20, Ownable {
    uint256 public buyTax = 2; // 2%
    uint256 public sellTax = 3; // 3%
    address public uniswapV2Pair;
    address public uniswapRouter;
    address public taxWallet;

    mapping(address => bool) public isExcludedFromTax;

    event TaxesUpdated(uint256 buyTax, uint256 sellTax);
    event TaxWalletUpdated(address newTaxWallet);

    constructor(address _router, address _taxWallet) ERC20("MANGO_DEFI", "MANGO") {
        _mint(msg.sender, 1_000_000 * 10**decimals());
        uniswapRouter = _router;
        taxWallet = _taxWallet;

        // Get Uniswap Pair Address
        IUniswapV2Router02 router = IUniswapV2Router02(_router);
        uniswapV2Pair = pairFor(router.factory(), address(this), router.WETH());

        // Exclude important addresses from tax
        isExcludedFromTax[owner()] = true;
        isExcludedFromTax[address(this)] = true;
        isExcludedFromTax[_router] = true; // ✅ Exclude Router from tax
        isExcludedFromTax[uniswapV2Pair] = true; // ✅ Exclude Pair from tax
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        uint256 taxAmount = 0;
        if (!isExcludedFromTax[from] && !isExcludedFromTax[to]) {
            if (to == uniswapV2Pair) {
                // Selling
                taxAmount = (amount * sellTax) / 100;
            } else if (from == uniswapV2Pair) {
                // Buying
                taxAmount = (amount * buyTax) / 100;
            }
        }
        uint256 amountAfterTax = amount - taxAmount;
        super._transfer(from, to, amountAfterTax);
        if (taxAmount > 0) {
            super._transfer(from, taxWallet, taxAmount);
        }
    }
    function setTaxes(uint256 _buyTax, uint256 _sellTax) external onlyOwner {
        require(_buyTax <= 10 && _sellTax <= 10, "Max tax is 10%");
        buyTax = _buyTax;
        sellTax = _sellTax;
        emit TaxesUpdated(_buyTax, _sellTax);
    }

    function setTaxWallet(address _taxWallet) external onlyOwner {
        require(_taxWallet != address(0), "Tax wallet cannot be the zero address");
        taxWallet = _taxWallet;
        emit TaxWalletUpdated(_taxWallet);
    }
}