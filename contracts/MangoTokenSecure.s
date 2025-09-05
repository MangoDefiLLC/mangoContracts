// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

/**
 * @title MangoTokenSecure
 * @dev Secure version of MANGO token with improved access control, timelock for critical changes, and enhanced security features
 */
contract MangoTokenSecure is ERC20, Ownable2Step, Pausable {
    using SafeMath for uint256;

    // Constants
    uint256 private constant MAX_TAX_RATE = 300; // 3% maximum tax
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant TIMELOCK_DURATION = 24 hours;
    
    // State variables
    uint256 public buyTax;
    uint256 public sellTax;
    address public uniswapRouter;
    address public taxWallet;
    
    // Mappings
    mapping(address => bool) public isExcludedFromTax;
    mapping(address => bool) public isPair;
    mapping(address => bool) public isBlacklisted;
    
    // Timelock for critical operations
    struct PendingChange {
        uint256 newBuyTax;
        uint256 newSellTax;
        address newTaxWallet;
        uint256 executeTime;
        bool exists;
    }
    PendingChange public pendingTaxChange;
    
    // Limits and controls
    bool public tradingEnabled;
    uint256 public maxTransactionAmount;
    uint256 public maxWalletAmount;
    mapping(address => uint256) public lastTransactionTime;
    uint256 public transactionCooldown = 1 seconds;
    
    // Events
    event TaxesUpdated(uint256 buyTax, uint256 sellTax);
    event TaxWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event PairAdded(address indexed pair);
    event PairRemoved(address indexed pair);
    event ExclusionUpdated(address indexed account, bool excluded);
    event BlacklistUpdated(address indexed account, bool blacklisted);
    event TradingEnabled(uint256 timestamp);
    event TaxChangeProposed(uint256 newBuyTax, uint256 newSellTax, address newTaxWallet, uint256 executeTime);
    event TaxChangeExecuted(uint256 buyTax, uint256 sellTax, address taxWallet);
    event TaxChangeCancelled();
    event TransactionLimitsUpdated(uint256 maxTransaction, uint256 maxWallet);

    // Custom errors
    error TaxTooHigh();
    error TradingNotEnabled();
    error Blacklisted();
    error ExceedsMaxTransaction();
    error ExceedsMaxWallet();
    error TransactionTooFrequent();
    error TimelockNotReady();
    error NoPendingChange();
    error InvalidAddress();
    error InvalidAmount();

    modifier whenTradingEnabled() {
        if (!tradingEnabled && !isExcludedFromTax[msg.sender]) {
            revert TradingNotEnabled();
        }
        _;
    }

    modifier notBlacklisted(address account) {
        if (isBlacklisted[account]) {
            revert Blacklisted();
        }
        _;
    }

    constructor(
        address _router, 
        address _taxWallet,
        uint256 _maxTransactionPercent, // e.g., 100 = 1%
        uint256 _maxWalletPercent // e.g., 200 = 2%
    ) ERC20("MANGO", "MANGO") {
        if (_router == address(0) || _taxWallet == address(0)) {
            revert InvalidAddress();
        }
        
        uint256 totalSupply = 100_000_000_000 * 10**decimals();
        _mint(msg.sender, totalSupply);
        
        uniswapRouter = _router;
        taxWallet = _taxWallet;
        
        // Set initial limits
        maxTransactionAmount = totalSupply.mul(_maxTransactionPercent).div(BASIS_POINTS);
        maxWalletAmount = totalSupply.mul(_maxWalletPercent).div(BASIS_POINTS);
        
        // Exclude key addresses from tax and limits
        isExcludedFromTax[msg.sender] = true;
        isExcludedFromTax[address(this)] = true;
        isExcludedFromTax[_router] = true;
        isExcludedFromTax[_taxWallet] = true;
    }

    /**
     * @dev Enhanced transfer function with security checks
     */
    function _transfer(address from, address to, uint256 amount) 
        internal 
        override 
        whenNotPaused 
        whenTradingEnabled
        notBlacklisted(from)
        notBlacklisted(to)
    {
        if (from == address(0) || to == address(0)) {
            revert InvalidAddress();
        }
        if (amount == 0) {
            revert InvalidAmount();
        }

        // Apply transaction limits for non-excluded addresses
        if (!isExcludedFromTax[from] && !isExcludedFromTax[to]) {
            _enforceTransactionLimits(from, to, amount);
        }

        uint256 taxAmount = 0;
        
        // Calculate tax only if not excluded
        if (!isExcludedFromTax[from] && !isExcludedFromTax[to]) {
            if (isPair[to] && sellTax > 0) {
                // Selling
                taxAmount = amount.mul(sellTax).div(BASIS_POINTS);
            } else if (isPair[from] && buyTax > 0) {
                // Buying
                taxAmount = amount.mul(buyTax).div(BASIS_POINTS);
            }
        }

        uint256 amountAfterTax = amount.sub(taxAmount);
        
        // Execute transfers
        super._transfer(from, to, amountAfterTax);
        
        if (taxAmount > 0) {
            super._transfer(from, taxWallet, taxAmount);
        }
    }

    /**
     * @dev Enforce transaction limits and cooldowns
     */
    function _enforceTransactionLimits(address from, address to, uint256 amount) internal {
        // Check transaction amount limit
        if (amount > maxTransactionAmount) {
            revert ExceedsMaxTransaction();
        }
        
        // Check wallet limit for buys
        if (isPair[from]) {
            uint256 newBalance = balanceOf(to).add(amount);
            if (newBalance > maxWalletAmount) {
                revert ExceedsMaxWallet();
            }
        }
        
        // Check transaction cooldown
        if (block.timestamp < lastTransactionTime[from].add(transactionCooldown)) {
            revert TransactionTooFrequent();
        }
        
        lastTransactionTime[from] = block.timestamp;
    }

    // ============ TIMELOCK TAX MANAGEMENT ============

    /**
     * @dev Propose tax changes with timelock
     */
    function proposeTaxChange(
        uint256 _buyTax, 
        uint256 _sellTax, 
        address _newTaxWallet
    ) external onlyOwner {
        if (_buyTax > MAX_TAX_RATE || _sellTax > MAX_TAX_RATE) {
            revert TaxTooHigh();
        }
        if (_newTaxWallet == address(0)) {
            revert InvalidAddress();
        }

        pendingTaxChange = PendingChange({
            newBuyTax: _buyTax,
            newSellTax: _sellTax,
            newTaxWallet: _newTaxWallet,
            executeTime: block.timestamp + TIMELOCK_DURATION,
            exists: true
        });

        emit TaxChangeProposed(_buyTax, _sellTax, _newTaxWallet, pendingTaxChange.executeTime);
    }

    /**
     * @dev Execute pending tax changes after timelock
     */
    function executeTaxChange() external onlyOwner {
        if (!pendingTaxChange.exists) {
            revert NoPendingChange();
        }
        if (block.timestamp < pendingTaxChange.executeTime) {
            revert TimelockNotReady();
        }

        buyTax = pendingTaxChange.newBuyTax;
        sellTax = pendingTaxChange.newSellTax;
        taxWallet = pendingTaxChange.newTaxWallet;

        emit TaxChangeExecuted(buyTax, sellTax, taxWallet);
        emit TaxesUpdated(buyTax, sellTax);
        emit TaxWalletUpdated(taxWallet, pendingTaxChange.newTaxWallet);

        // Clear pending change
        delete pendingTaxChange;
    }

    /**
     * @dev Cancel pending tax changes
     */
    function cancelTaxChange() external onlyOwner {
        if (!pendingTaxChange.exists) {
            revert NoPendingChange();
        }

        delete pendingTaxChange;
        emit TaxChangeCancelled();
    }

    // ============ PAIR AND EXCLUSION MANAGEMENT ============

    /**
     * @dev Add trading pair
     */
    function addPair(address pair) external onlyOwner {
        if (pair == address(0)) {
            revert InvalidAddress();
        }
        
        isPair[pair] = true;
        isExcludedFromTax[pair] = true;
        
        emit PairAdded(pair);
    }

    /**
     * @dev Remove trading pair
     */
    function removePair(address pair) external onlyOwner {
        isPair[pair] = false;
        isExcludedFromTax[pair] = false;
        
        emit PairRemoved(pair);
    }

    /**
     * @dev Update tax exclusion status
     */
    function setExcludedFromTax(address account, bool excluded) external onlyOwner {
        if (account == address(0)) {
            revert InvalidAddress();
        }
        
        isExcludedFromTax[account] = excluded;
        emit ExclusionUpdated(account, excluded);
    }

    /**
     * @dev Batch update tax exclusions
     */
    function batchSetExcludedFromTax(address[] calldata accounts, bool excluded) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0)) {
                isExcludedFromTax[accounts[i]] = excluded;
                emit ExclusionUpdated(accounts[i], excluded);
            }
        }
    }

    // ============ BLACKLIST MANAGEMENT ============

    /**
     * @dev Update blacklist status
     */
    function setBlacklisted(address account, bool blacklisted) external onlyOwner {
        if (account == address(0)) {
            revert InvalidAddress();
        }
        
        isBlacklisted[account] = blacklisted;
        emit BlacklistUpdated(account, blacklisted);
    }

    /**
     * @dev Batch update blacklist
     */
    function batchSetBlacklisted(address[] calldata accounts, bool blacklisted) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0)) {
                isBlacklisted[accounts[i]] = blacklisted;
                emit BlacklistUpdated(accounts[i], blacklisted);
            }
        }
    }

    // ============ TRADING CONTROLS ============

    /**
     * @dev Enable trading (one-time action)
     */
    function enableTrading() external onlyOwner {
        if (!tradingEnabled) {
            tradingEnabled = true;
            emit TradingEnabled(block.timestamp);
        }
    }

    /**
     * @dev Update transaction limits
     */
    function setTransactionLimits(
        uint256 _maxTransactionPercent, 
        uint256 _maxWalletPercent
    ) external onlyOwner {
        uint256 totalSupply = totalSupply();
        
        maxTransactionAmount = totalSupply.mul(_maxTransactionPercent).div(BASIS_POINTS);
        maxWalletAmount = totalSupply.mul(_maxWalletPercent).div(BASIS_POINTS);
        
        emit TransactionLimitsUpdated(maxTransactionAmount, maxWalletAmount);
    }

    /**
     * @dev Set transaction cooldown
     */
    function setTransactionCooldown(uint256 _cooldown) external onlyOwner {
        require(_cooldown <= 60, "Cooldown too long"); // Max 1 minute
        transactionCooldown = _cooldown;
    }

    // ============ EMERGENCY FUNCTIONS ============

    /**
     * @dev Pause contract in emergency
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Get pending tax change details
     */
    function getPendingTaxChange() external view returns (
        uint256 newBuyTax,
        uint256 newSellTax,
        address newTaxWallet,
        uint256 executeTime,
        bool exists
    ) {
        PendingChange memory change = pendingTaxChange;
        return (
            change.newBuyTax,
            change.newSellTax,
            change.newTaxWallet,
            change.executeTime,
            change.exists
        );
    }

    /**
     * @dev Check if tax change is ready to execute
     */
    function isTaxChangeReady() external view returns (bool) {
        return pendingTaxChange.exists && block.timestamp >= pendingTaxChange.executeTime;
    }

    /**
     * @dev Get effective tax rate for a transaction
     */
    function getEffectiveTaxRate(address from, address to) external view returns (uint256) {
        if (isExcludedFromTax[from] || isExcludedFromTax[to]) {
            return 0;
        }
        
        if (isPair[to]) {
            return sellTax; // Selling
        } else if (isPair[from]) {
            return buyTax; // Buying
        }
        
        return 0; // No tax for regular transfers
    }

    // ============ OVERRIDES ============

    /**
     * @dev Override _beforeTokenTransfer to add additional checks
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        
        // Additional pre-transfer validations can be added here
    }
}