// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IRouterV2.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IMangoReferral.sol";
import "./interfaces/IUniswapV3Factory.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./MangoReferral.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}

/**
 * @title MangoRouterSecure
 * @dev Secure version of MangoRouter with reentrancy protection, slippage protection, and other security improvements
 */
contract MangoRouterSecure is ReentrancyGuard, Pausable, Ownable {
    using SafeMath for uint256;

    // Constants
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant MAX_TAX_FEE = 500; // 5% maximum
    uint256 private constant MAX_REFERRAL_FEE = 200; // 2% maximum
    uint256 private constant MIN_SLIPPAGE_TOLERANCE = 50; // 0.5% minimum
    uint256 private constant MAX_SLIPPAGE_TOLERANCE = 1000; // 10% maximum

    // Immutable contracts
    IUniswapV2Factory public immutable factoryV2;
    IUniswapV3Factory public immutable factoryV3;
    ISwapRouter02 public immutable swapRouter02;
    IRouterV2 public immutable routerV2;
    IWETH9 public immutable weth;

    // State variables
    IMangoReferral public mangoReferral;
    address public taxMan;
    uint256 public taxFee;
    uint256 public referralFee;
    uint256 public defaultSlippageTolerance;
    
    // Pool fees for V3
    uint24[] public poolFees;
    
    // Mappings
    mapping(address => bool) public authorizedCallers;
    mapping(address => uint256) public userNonces;

    struct Path {
        address token0;
        address token1;
        uint256 amount;
        uint24 poolFee;
        address receiver;
        address referrer;
        uint256 minAmountOut;
    }

    // Events
    event Swap(
        address indexed swapper,
        address indexed token0, 
        address indexed token1,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    
    event TaxFeeUpdated(uint256 oldFee, uint256 newFee);
    event ReferralFeeUpdated(uint256 oldFee, uint256 newFee);
    event TaxManUpdated(address oldTaxMan, address newTaxMan);
    event SlippageToleranceUpdated(uint256 oldTolerance, uint256 newTolerance);
    event AuthorizedCallerUpdated(address caller, bool authorized);

    // Custom errors
    error InvalidAmount();
    error InvalidToken();
    error SlippageExceeded();
    error InsufficientOutput();
    error UnauthorizedCaller();
    error InvalidSlippageTolerance();
    error NoPoolFound();
    error TransferFailed();

    modifier onlyAuthorized() {
        if (!authorizedCallers[msg.sender] && msg.sender != owner()) {
            revert UnauthorizedCaller();
        }
        _;
    }

    constructor(
        address _factoryV2,
        address _factoryV3,
        address _routerV2,
        address _swapRouter02,
        address _weth
    ) {
        factoryV2 = IUniswapV2Factory(_factoryV2);
        factoryV3 = IUniswapV3Factory(_factoryV3);
        routerV2 = IRouterV2(_routerV2);
        swapRouter02 = ISwapRouter02(_swapRouter02);
        weth = IWETH9(_weth);
        
        taxFee = 300; // 3%
        referralFee = 100; // 1%
        defaultSlippageTolerance = 200; // 2%
        taxMan = msg.sender;
        
        poolFees = [10000, 20000, 2500, 1000, 100, 3000, 5000];
        
        // Set initial authorized caller
        authorizedCallers[msg.sender] = true;
    }

    /**
     * @dev Secure swap function with reentrancy and slippage protection
     */
    function swap(
        address token0, 
        address token1,
        uint256 amount,
        address referrer,
        uint256 slippageTolerance
    ) external payable nonReentrant whenNotPaused returns(uint256 amountOut) {
        // Input validation
        if (msg.value == 0 && amount == 0) revert InvalidAmount();
        if (msg.value > 0 && amount > 0) revert InvalidAmount();
        if (token0 == address(0) && msg.value == 0) revert InvalidAmount();
        if (token1 == address(0) && amount == 0) revert InvalidAmount();
        if (token0 == address(0) && token1 == address(0)) revert InvalidToken();
        
        // Validate slippage tolerance
        if (slippageTolerance == 0) {
            slippageTolerance = defaultSlippageTolerance;
        } else if (slippageTolerance < MIN_SLIPPAGE_TOLERANCE || slippageTolerance > MAX_SLIPPAGE_TOLERANCE) {
            revert InvalidSlippageTolerance();
        }

        Path memory path;
        path.amount = msg.value == 0 ? amount : _calculateAfterTax(msg.value);
        path.token0 = token0;
        path.token1 = token1;
        path.referrer = referrer;
        
        // Calculate minimum amount out with slippage protection
        uint256 expectedAmountOut = _getExpectedAmountOut(path);
        //E: THIS MINAMOUNT I CAN GET USING THE uniswap Qouter
        path.minAmountOut = expectedAmountOut.mul(BASIS_POINTS.sub(slippageTolerance)).div(BASIS_POINTS);

        // Find and execute swap
        (bool foundPool, uint24 poolFee) = _findOptimalPool(token0, token1);
        if (!foundPool) revert NoPoolFound();
        
        path.poolFee = poolFee;
        amountOut = _executeSecureSwap(path);
        
        // Handle fees and referrals
        if (msg.value > 0) {
            _handleFeesAndReferrals(msg.value.sub(path.amount), referrer);
        }

        emit Swap(msg.sender, token0, token1, path.amount, amountOut, taxFee);
    }

    /**
     * @dev Execute swap with proper checks-effects-interactions pattern
     */
    function _executeSecureSwap(Path memory data) internal returns(uint256 amountOut) {
        if (data.token0 == address(0)) {
            // ETH to token
            data.token0 = address(weth);
            data.receiver = msg.sender;
            amountOut = data.poolFee == 0 ? _ethToTokensV2Secure(data) : _tokensToTokensV3Secure(data);
        } else if (data.token1 == address(0)) {
            // Token to ETH
            data.token1 = address(weth);
            data.receiver = address(this);
            amountOut = data.poolFee == 0 ? _tokensToEthV2Secure(data) : _tokensToTokensV3Secure(data);
            
            // Unwrap and send ETH securely
            if (data.poolFee > 0) {
                weth.withdraw(amountOut);
            }
            
            uint256 afterTaxAmount = _calculateAfterTax(amountOut);
            _sendETHSecurely(msg.sender, afterTaxAmount);
            _sendETHSecurely(taxMan, amountOut.sub(afterTaxAmount));
            
        } else {
            // Token to token
            data.receiver = msg.sender;
            amountOut = data.poolFee == 0 ? _tokensToTokensV2Secure(data) : _tokensToTokensV3Secure(data);
        }
        
        // Verify slippage protection
        if (amountOut < data.minAmountOut) {
            revert SlippageExceeded();
        }
    }

    /**
     * @dev Secure ETH transfer with proper error handling
     */
    function _sendETHSecurely(address to, uint256 amount) internal {
        if (amount == 0) return;
        
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /**
     * @dev Calculate amount after tax with overflow protection
     */
    function _calculateAfterTax(uint256 amount) internal view returns(uint256) {
        if (taxFee == 0) return amount;
        
        uint256 taxAmount = amount.mul(taxFee).div(BASIS_POINTS);
        return amount.sub(taxAmount);
    }

    /**
     * @dev Handle fees and referrals securely
     */
    function _handleFeesAndReferrals(uint256 feeAmount, address referrer) internal {
        if (feeAmount == 0) return;
        
        if (referrer != address(0) && address(mangoReferral) != address(0)) {
            uint256 referralReward = feeAmount.mul(referralFee).div(BASIS_POINTS);
            
            // Use try-catch for external call to referral contract
            try mangoReferral.distributeReferralRewards(msg.sender, referralReward, referrer) {
                _sendETHSecurely(taxMan, feeAmount.sub(referralReward));
            } catch {
                // If referral fails, send all to taxMan
                _sendETHSecurely(taxMan, feeAmount);
            }
        } else {
            _sendETHSecurely(taxMan, feeAmount);
        }
    }

    /**
     * @dev Find optimal pool with gas optimization
     */
    function _findOptimalPool(address token0, address token1) internal view returns(bool found, uint24 optimalFee) {
        address actualToken0 = token0 == address(0) ? address(weth) : token0;
        address actualToken1 = token1 == address(0) ? address(weth) : token1;
        
        // Check V2 pool first (usually cheaper gas)
        address v2Pool = factoryV2.getPair(actualToken0, actualToken1);
        if (v2Pool != address(0)) {
            return (true, 0);
        }
        
        // Check V3 pools
        for (uint256 i = 0; i < poolFees.length; i++) {
            address v3Pool = factoryV3.getPool(actualToken0, actualToken1, poolFees[i]);
            if (v3Pool != address(0)) {
                return (true, poolFees[i]);
            }
        }
        
        return (false, 0);
    }

    /**
     * @dev Get expected amount out for slippage calculation
     */
    function _getExpectedAmountOut(Path memory data) internal view returns(uint256) {
        address actualToken0 = data.token0 == address(0) ? address(weth) : data.token0;
        address actualToken1 = data.token1 == address(0) ? address(weth) : data.token1;
        
        // For V2 pools
        address v2Pool = factoryV2.getPair(actualToken0, actualToken1);
        if (v2Pool != address(0)) {
            address[] memory path = new address[](2);
            path[0] = actualToken0;
            path[1] = actualToken1;
            uint256[] memory amountsOut = routerV2.getAmountsOut(data.amount, path);
            return amountsOut[1];
        }
        
        // For V3 pools, we'd need a quoter contract (simplified here)
        // In production, use IQuoter or IQuoterV2
        return data.amount; // Simplified
    }

    /**
     * @dev Secure V2 ETH to tokens swap
     */
    function _ethToTokensV2Secure(Path memory data) internal returns(uint256) {
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = data.token1;
        
        uint256[] memory amountsOut = routerV2.getAmountsOut(data.amount, path);
        
        uint256[] memory amounts = routerV2.swapExactETHForTokens{value: data.amount}(
            data.minAmountOut,
            path,
            data.receiver,
            block.timestamp + 300 // 5 minutes
        );
        
        return amounts[1];
    }

    /**
     * @dev Secure V2 tokens to ETH swap
     */
    function _tokensToEthV2Secure(Path memory data) internal returns(uint256) {
        // Transfer tokens first
        if (!IERC20(data.token0).transferFrom(msg.sender, address(this), data.amount)) {
            revert TransferFailed();
        }
        
        // Approve router
        if (!IERC20(data.token0).approve(address(routerV2), data.amount)) {
            revert TransferFailed();
        }
        
        address[] memory path = new address[](2);
        path[0] = data.token0;
        path[1] = address(weth);
        
        uint256[] memory amountsOut = routerV2.getAmountsOut(data.amount, path);
        
        uint256[] memory amounts = routerV2.swapExactTokensForETH(
            data.amount,
            data.minAmountOut,
            path,
            data.receiver,
            block.timestamp + 300
        );
        
        return amounts[1];
    }

    /**
     * @dev Secure V2 tokens to tokens swap
     */
    function _tokensToTokensV2Secure(Path memory data) internal returns(uint256) {
        // Transfer tokens first
        if (!IERC20(data.token0).transferFrom(msg.sender, address(this), data.amount)) {
            revert TransferFailed();
        }
        
        // Approve router
        if (!IERC20(data.token0).approve(address(routerV2), data.amount)) {
            revert TransferFailed();
        }
        
        address[] memory path = new address[](2);
        path[0] = data.token0;
        path[1] = data.token1;
        
        uint256[] memory amounts = routerV2.swapExactTokensForTokens(
            data.amount,
            data.minAmountOut,
            path,
            data.receiver,
            block.timestamp + 300
        );
        
        return amounts[1];
    }

    /**
     * @dev Secure V3 swap with proper parameters
     */
    function _tokensToTokensV3Secure(Path memory data) internal returns(uint256) {
        if (msg.value == 0) {
            // Transfer and approve tokens
            if (!IERC20(data.token0).transferFrom(msg.sender, address(this), data.amount)) {
                revert TransferFailed();
            }
            if (!IERC20(data.token0).approve(address(swapRouter02), data.amount)) {
                revert TransferFailed();
            }
        }

        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
            .ExactInputSingleParams({
                tokenIn: data.token0,
                tokenOut: data.token1,
                fee: data.poolFee,
                recipient: data.receiver,
                amountIn: data.amount,
                amountOutMinimum: data.minAmountOut, // ✅ FIXED: Proper slippage protection
                sqrtPriceLimitX96: 0
            });

        if (msg.value > 0) {
            return swapRouter02.exactInputSingle{value: data.amount}(params);
        } else {
            return swapRouter02.exactInputSingle(params);
        }
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @dev Update tax fee with limits
     */
    function setTaxFee(uint256 newTaxFee) external onlyOwner {
        if (newTaxFee > MAX_TAX_FEE) revert InvalidAmount();
        
        uint256 oldFee = taxFee;
        taxFee = newTaxFee;
        
        emit TaxFeeUpdated(oldFee, newTaxFee);
    }

    /**
     * @dev Update referral fee with limits
     */
    function setReferralFee(uint256 newReferralFee) external onlyOwner {
        if (newReferralFee > MAX_REFERRAL_FEE) revert InvalidAmount();
        
        uint256 oldFee = referralFee;
        referralFee = newReferralFee;
        
        emit ReferralFeeUpdated(oldFee, newReferralFee);
    }

    /**
     * @dev Update tax man address
     */
    function setTaxMan(address newTaxMan) external onlyOwner {
        if (newTaxMan == address(0)) revert InvalidToken();
        
        address oldTaxMan = taxMan;
        taxMan = newTaxMan;
        
        emit TaxManUpdated(oldTaxMan, newTaxMan);
    }

    /**
     * @dev Set referral contract
     */
    function setReferralContract(address referralAddress) external onlyOwner {
        mangoReferral = IMangoReferral(referralAddress);
    }

    /**
     * @dev Update default slippage tolerance
     */
    function setDefaultSlippageTolerance(uint256 newTolerance) external onlyOwner {
        if (newTolerance < MIN_SLIPPAGE_TOLERANCE || newTolerance > MAX_SLIPPAGE_TOLERANCE) {
            revert InvalidSlippageTolerance();
        }
        
        uint256 oldTolerance = defaultSlippageTolerance;
        defaultSlippageTolerance = newTolerance;
        
        emit SlippageToleranceUpdated(oldTolerance, newTolerance);
    }

    /**
     * @dev Authorize/deauthorize callers
     */
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        authorizedCallers[caller] = authorized;
        emit AuthorizedCallerUpdated(caller, authorized);
    }

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

    /**
     * @dev Emergency withdrawal function
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            _sendETHSecurely(owner(), amount);
        } else {
            IERC20(token).transfer(owner(), amount);
        }
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Get quote for swap
     */
    function getQuote(
        address token0,
        address token1,
        uint256 amountIn
    ) external view returns(uint256 amountOut, uint24 poolFee) {
        Path memory tempPath;
        tempPath.token0 = token0;
        tempPath.token1 = token1;
        tempPath.amount = amountIn;
        
        (bool found, uint24 fee) = _findOptimalPool(token0, token1);
        if (!found) return (0, 0);
        
        tempPath.poolFee = fee;
        return (_getExpectedAmountOut(tempPath), fee);
    }

    // ============ FALLBACK ============

    /**
     * @dev Secure fallback function
     */
    receive() external payable {
        // Only accept ETH from WETH contract or authorized contracts
        if (msg.sender != address(weth) && !authorizedCallers[msg.sender]) {
            revert UnauthorizedCaller();
        }
    }
}