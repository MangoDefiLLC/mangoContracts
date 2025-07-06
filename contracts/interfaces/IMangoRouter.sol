pragma solidity ^0.8.13;
interface IMangoRouter {
    function swap(
        address token0,
        address token1,
        uint256 amount,
        address referrer
        ) external payable returns(uint amountOut);
}