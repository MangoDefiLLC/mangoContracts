// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IMangoRouter} from "../../contracts/interfaces/IMangoRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockRouter is IMangoRouter {
    address public tokenOut;
    uint256 public fixedAmountOut = 1000e18; // Fixed return amount
    bool public shouldRevert = false;

    constructor(address _tokenOut) {
        tokenOut = _tokenOut;
    }

    function swap(
        address token0,
        address token1,
        uint256 amount,
        address referrer
    ) external payable returns (uint256 amountOut) {
        if (shouldRevert) revert("MockRouter: swap failed");
        
        // Simulate swap: when swapping ETH (token0 == address(0)) to token1
        // The router receives ETH and should send tokens to the caller
        if (token0 == address(0) && token1 != address(0)) {
            // Mint tokens to the caller (manager contract) to simulate swap
            MockERC20(token1).mint(msg.sender, fixedAmountOut);
            return fixedAmountOut;
        }
        
        return fixedAmountOut;
    }

    function setFixedAmountOut(uint256 amount) external {
        fixedAmountOut = amount;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }
}

