// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMangoReferral {

    function getReferralChain(
        address swapper
        ) external view returns (address);

        function addRouter(address router) external;

        function depositTokens(address token, uint256 amount) external;

        function addToken(address token) external;
        function distributeReferralRewards(
        address userAddress,//msg.sender the one initiated the swap
        uint256 inputAmount,//amount to distribute IF THIS AMOUNT IS NOT 0, SWAP TOKEN TO ETH
        address referrer// the referrer
    ) external payable;

}