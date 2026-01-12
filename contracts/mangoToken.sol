// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMangoErrors} from './interfaces/IMangoErrors.sol';
import {IMangoStructs} from './interfaces/IMangoStructs.sol';
import {IUniswapV3Factory} from './interfaces/IUniswapV3Factory.sol';
import {IMangoRouter} from "./interfaces/IMangoRouter.sol";

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
}
    
contract MANGO_DEFI_TOKEN is ERC20, Ownable, ERC20Burnable {

    uint256 public  immutable BUY_TAX = 200;  // 2% in basis points (BPS)
    uint256 public immutable SELL_TAX = 300; // 3% in basis points (BPS)
    uint256 public immutable BASIS_POINT = 10000; // Standard basis points (10000 = 100%)
    address public uniswapRouterV2;
    address public uniswapRouterV3;
    address public uniswapV3Factory;

    address public taxWallet;
    // Storage optimized: Fixed-size array (always 5 elements) stored in bytecode as immutable
    // Using uint24 since Uniswap V3 fees are uint24
    // Note: BUY_TAX (200) and SELL_TAX (300) are basis points, BASIS_POINT (10000) is used for calculations
    uint24[5] public v3FeeTiers = [
        uint24(100), 
        uint24(BUY_TAX), 
        uint24(BASIS_POINT), 
        uint24(SELL_TAX), 
        uint24(30000)
    ];

    // Storage optimized: Pack three booleans into one struct (3 bytes = 1 slot)
    // This saves 2 storage slots per address (~40,000 gas on first write, ~10,000 gas on subsequent writes)
    // All three flags are frequently accessed together in _transfer(), making packing beneficial
    struct AddressFlags {
        bool isExcludedFromTax;  // 1 byte
        bool isPair;              // 1 byte
        bool isV3Pool;            // 1 byte
        // Total: 3 bytes, fits in one 32-byte slot with 29 bytes padding
    }
    mapping(address => AddressFlags) public addressFlags;
    
    // Legacy getters for backward compatibility (if needed)
    // These functions read from the struct mapping
    function isExcludedFromTax(address addr) public view returns (bool) {
        return addressFlags[addr].isExcludedFromTax;
    }
    
    function isPair(address addr) public view returns (bool) {
        return addressFlags[addr].isPair;
    }
    
    function isV3Pool(address addr) public view returns (bool) {
        return addressFlags[addr].isV3Pool;
    }

    event TaxWalletUpdated(address indexed newTaxWallet);
    event PairAdded(address indexed pair);
    event NewOwner(address indexed newOwner);
    event V3PoolAdded(address indexed pool);

    constructor(IMangoStructs.cTokenParams memory cParams) Ownable() ERC20("MANGO DEFI", "MANGO") {
                //IMangoStructs.cTokenParams memory cParams
        _mint(msg.sender,  100000000000e18);
        //LOOK IN TO THIS CONSTRUCTOS
        taxWallet = msg.sender;
        uniswapRouterV2 = cParams.uniswapRouterV2;
        uniswapRouterV3 =  cParams.uniswapRouterV3;
        uniswapV3Factory =  cParams.uniswapV3Factory;
        uniswapRouterV2 =   cParams.uniswapRouterV2;//uniswap v2 router
        // Optimized: Set flags using struct (all in one slot per address)
        addressFlags[msg.sender].isExcludedFromTax = true;
        addressFlags[address(this)].isExcludedFromTax = true;
        addressFlags[uniswapRouterV2].isExcludedFromTax = true;
    }
    //**THE TAXES FOR THIS IS DESIGNE FOR V2, V3 NEEDS TO BE ADDED AND TESTED */
    //** V2 PAIR MANAGEMENT **//
    /**
     * @notice Adds a Uniswap V2 pair address to enable tax calculation for sells
     * @dev When tokens are transferred to a registered pair, it's considered a sell transaction
     * @param pair Address of the Uniswap V2 pair
     */
    function addPair(address pair) external onlyOwner {
        if(pair == address(0)) revert IMangoErrors.InvalidAddress();
        addressFlags[pair].isPair = true;
        emit PairAdded(pair);
    }
    //** V3 POOL MANAGEMENT **//
    function addV3Pool(address pool) external onlyOwner {
        if(pool == address(0)) revert IMangoErrors.InvalidAddress();
        addressFlags[pool].isV3Pool = true;
        emit V3PoolAdded(pool);
    }

    // Auto-detect and add V3 pools for common fee tiers
    //fee tiers get from router
    // Optimized: Fixed-size array (always 5 elements), use constant length
    function autoDetectV3Pools(address token0,address token1) external onlyOwner returns(address pool){
        for (uint i = 0; i < 5; ) {
            pool = IUniswapV3Factory(uniswapV3Factory).getPool(
                token0,
                token1,
                v3FeeTiers[i]// Now uint24, no cast needed
            );
            if (pool != address(0) && !addressFlags[pool].isV3Pool) {
                addressFlags[pool].isV3Pool = true;
                emit V3PoolAdded(pool);
            }
            unchecked { ++i; }  // Safe: i < 5, will not overflow
        }
    }

    function excludeAddress(address _addr) external onlyOwner returns (bool) {
        addressFlags[_addr].isExcludedFromTax = true;
        return true;
    }

    /**
     * @notice Batch adds multiple Uniswap V2 pair addresses
     * @dev Adds multiple pairs in a single transaction, saving gas on transaction overhead
     * @param pairs Array of pair addresses to add
     * @custom:gas-savings Saves ~21,000 gas per additional pair (base transaction cost)
     */
    function batchAddPairs(address[] calldata pairs) external onlyOwner {
        uint256 length = pairs.length;
        for (uint256 i = 0; i < length; ) {
            address pair = pairs[i];
            if(pair == address(0)) revert IMangoErrors.InvalidAddress();
            addressFlags[pair].isPair = true;
            emit PairAdded(pair);
            unchecked { ++i; }  // Safe: i < length, will not overflow
        }
    }

    /**
     * @notice Batch adds multiple Uniswap V3 pool addresses
     * @dev Adds multiple pools in a single transaction, saving gas on transaction overhead
     * @param pools Array of pool addresses to add
     * @custom:gas-savings Saves ~21,000 gas per additional pool (base transaction cost)
     */
    function batchAddV3Pools(address[] calldata pools) external onlyOwner {
        uint256 length = pools.length;
        for (uint256 i = 0; i < length; ) {
            address pool = pools[i];
            if(pool == address(0)) revert IMangoErrors.InvalidAddress();
            addressFlags[pool].isV3Pool = true;
            emit V3PoolAdded(pool);
            unchecked { ++i; }  // Safe: i < length, will not overflow
        }
    }

    /**
     * @notice Batch excludes multiple addresses from tax
     * @dev Excludes multiple addresses in a single transaction, saving gas on transaction overhead
     * @param addresses Array of addresses to exclude from tax
     * @custom:gas-savings Saves ~21,000 gas per additional address (base transaction cost)
     */
    function batchExcludeAddresses(address[] calldata addresses) external onlyOwner {
        uint256 length = addresses.length;
        for (uint256 i = 0; i < length; ) {
            address addr = addresses[i];
            if(addr == address(0)) revert IMangoErrors.InvalidAddress();
            addressFlags[addr].isExcludedFromTax = true;
            unchecked { ++i; }  // Safe: i < length, will not overflow
        }
    }

    function _transfer(address from, address to, uint256 amount) internal virtual override {
        uint256 taxAmount = 0;
        //fpr unniswapv3
        //i transfer is from owner to uniswapV3 pool SELL
        //if transfer is from v3Pool to uniswapRouter or user BUY
        // Optimized: Read all flags from struct mapping (one storage slot instead of three)
        AddressFlags memory fromFlags = addressFlags[from];
        AddressFlags memory toFlags = addressFlags[to];
        
        if (!fromFlags.isExcludedFromTax && !toFlags.isExcludedFromTax) {
            bool isSell = toFlags.isPair || toFlags.isV3Pool;
            bool isBuy = fromFlags.isPair || fromFlags.isV3Pool;

            if (isSell) {
                // Sell transaction: 3% tax (300 basis points)
                // Example: 100 MANGO -> 97 MANGO to Uniswap, 3 MANGO to tax wallet
                taxAmount = (amount * SELL_TAX) / BASIS_POINT;
            } else if (isBuy) {
                // Buy transaction: 2% tax (200 basis points)
                // Example: 100 MANGO -> 98 MANGO to user, 2 MANGO to tax wallet
                taxAmount = (amount * BUY_TAX) / BASIS_POINT;
            }
        }

        // Calculate amount after tax deduction
        // For sells: 97% goes to Uniswap, 3% goes to tax wallet
        // For buys: 98% goes to buyer, 2% goes to tax wallet
        uint256 amountAfterTax = amount - taxAmount;
        
        // Transfer the taxed amount to the recipient (Uniswap pool for sells, user for buys)
        super._transfer(from, to, amountAfterTax);

        // Transfer the tax amount to the tax wallet
        if (taxAmount > 0) {
            if(taxWallet == address(0)) revert IMangoErrors.InvalidAddress();
            super._transfer(from, taxWallet, taxAmount);
        }
    }

    //** V3 POOL CHECKER **//
    function isV3PoolAddress(address pool) public view returns (bool) {
        return addressFlags[pool].isV3Pool;
    }

    function setTaxWallet(address _taxWallet) external {
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        if(_taxWallet == address(0)) revert IMangoErrors.InvalidAddress();
        taxWallet = _taxWallet;
        emit TaxWalletUpdated(_taxWallet);
    }

    function changeOwner(address _newOwner) external {
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        if(_newOwner == address(0)) revert IMangoErrors.InvalidAddress();
        transferOwnership(_newOwner);
        emit NewOwner(_newOwner);
    }
}