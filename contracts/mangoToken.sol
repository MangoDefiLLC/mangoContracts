// SPDX-License-Identifier: MIT
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
    
contract mockMANGO_DEFI_TOKEN is ERC20, Ownable, ERC20Burnable {

    uint256 public  immutable BUY_TAX = 200;  // 2% in basis points (BPS)
    uint256 public immutable SELL_TAX = 300; // 3% in basis points (BPS)
    uint256 public immutable BASIS_POINT = 1000;
    address public uniswapRouterV2;
    address public uniswapRouterV3;
    address public uniswapV3Factory;

    address public taxWallet;
    uint256[] public v3FeeTiers = [100,BUY_TAX,BASIS_POINT,SELL_TAX,30000];

    mapping(address => bool) public isExcludedFromTax;
    mapping(address => bool) public isPair;
    mapping(address => bool) public isV3Pool;

    event TaxWalletUpdated(address newTaxWallet);
    event PairAdded(address pair);
    event NewOwner(address newOwner);
    event V3PoolAdded(address);

    constructor(IMangoStructs.cTokenParams memory cParams) Ownable() ERC20("mockMANGO DEFI", "MANGO") {
                //IMangoStructs.cTokenParams memory cParams
        _mint(msg.sender,  100000000000e18);
        //LOOK IN TO THIS CONSTRUCTOS
        taxWallet = msg.sender;
        uniswapRouterV2 = cParams.uniswapRouterV2;
        uniswapRouterV3 =  cParams.uniswapRouterV3;
        uniswapV3Factory =  cParams.uniswapV3Factory;
        uniswapRouterV2 =   cParams.uniswapRouterV2;//uniswap v2 router
        isExcludedFromTax[msg.sender] = true;
        isExcludedFromTax[address(this)] = true;
        isExcludedFromTax[uniswapRouterV2] = true;
    }
    //**THE TAXES FOR THIS IS DESIGNE FOR V2, V3 NEEDS TO BE ADDED AND TESTED */
    //** V2 PAIR MANAGEMENT **//
    function addPair(address pair) external onlyOwner {
        require(pair != address(0), "Invalid pair address");
        isPair[pair] = true;
        emit PairAdded(pair);
    }
    //** V3 POOL MANAGEMENT **//
    function addV3Pool(address pool) external onlyOwner {
        require(pool != address(0), "Invalid pool address");
        isV3Pool[pool] = true;
        emit V3PoolAdded(pool);
    }

    // Auto-detect and add V3 pools for common fee tiers
    //fee tiers get from router
    function autoDetectV3Pools(address token0,address token1) external onlyOwner returns(address pool){
        for (uint i = 0; i < v3FeeTiers.length; i++) {
            pool = IUniswapV3Factory(uniswapV3Factory).getPool(
                token0,
                token1,
                uint24(v3FeeTiers[i])
            );
            if (pool != address(0) && !isV3Pool[pool]) {
                isV3Pool[pool] = true;
                emit V3PoolAdded(pool);
            }
        }
    }

    function excludeAddress(address _addr) external onlyOwner returns (bool) {
        isExcludedFromTax[_addr] = true;
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual override {
        uint256 taxAmount = 0;

        if (!isExcludedFromTax[from] && !isExcludedFromTax[to]) {
            bool isSell = isPair[to] || isV3Pool[to];
            bool isBuy = isPair[from] || isV3Pool[from];

            if (isSell) {
                // Sell transaction
                taxAmount = (amount * SELL_TAX) / BASIS_POINT;
            } else if (isBuy) {
                // Buy transaction
                taxAmount = (amount * BUY_TAX) / BASIS_POINT;
            }
        }

        uint256 amountAfterTax = amount - taxAmount;
        super._transfer(from, to, amountAfterTax);

        if (taxAmount > 0) {
            super._transfer(from, taxWallet, taxAmount);
        }
    }

    //** V3 POOL CHECKER **//
    function isV3PoolAddress(address pool) public view returns (bool) {
        return isV3Pool[pool];
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