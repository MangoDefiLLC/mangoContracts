// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/ERC20.sol";

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

contract MANGO_DEFI is ERC20 {
    address public owner;
    uint256 public buyTax = 0; // 2%
    uint256 public sellTax = 0; // 3%
    address public uniswapRouter;
    address public taxWallet;

    mapping(address => bool) public isExcludedFromTax;
    mapping(address => bool) public isPair; // Allows multiple pools (V2, V3, V4)

    event TaxesUpdated(uint256 buyTax, uint256 sellTax);
    event TaxWalletUpdated(address newTaxWallet);
    event PairAdded(address pair);
    event NewOwner(address _newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(address _router, address _taxWallet) ERC20("MANGO", "MANGO") {
        owner = msg.sender;
        _mint(owner, 100_000_000_000 * 10**decimals());
        uniswapRouter = _router;
        taxWallet = _taxWallet;

        // Exclude key addresses from tax
        isExcludedFromTax[owner] = true;
        isExcludedFromTax[address(this)] = true;
        isExcludedFromTax[_router] = true;
    }

    function addPair(address pair) external onlyOwner {
        require(pair != address(0), "Invalid pair address");
        isPair[pair] = true;
        isExcludedFromTax[pair] = true;
        emit PairAdded(pair);
    }
    function excludeAddress(address _contract) external  onlyOwner returns(bool){
        require(msg.sender == owner);
        // to be able to add new mango router versions
        isExcludedFromTax[_contract] = true;
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        uint256 taxAmount = 0;

        if (!isExcludedFromTax[from] && !isExcludedFromTax[to]) {
            if (isPair[to]) {
                // Selling
                taxAmount = (amount * sellTax) / 100;
            } else if (isPair[from]) {
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
        require(_buyTax <= 3 && _sellTax <= 3, "Max tax is 3%");
        buyTax = _buyTax;
        sellTax = _sellTax;
        emit TaxesUpdated(_buyTax, _sellTax);
    }

    function setTaxWallet(address _taxWallet) external onlyOwner {
        require(_taxWallet != address(0), "Tax wallet cannot be zero address");
        taxWallet = _taxWallet;
        emit TaxWalletUpdated(_taxWallet);
    }
    function changeOwner(address _newOwner) external onlyOwner{
        owner = _newOwner;
        emit  NewOwner(owner);
    }
}
