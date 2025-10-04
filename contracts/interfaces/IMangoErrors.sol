// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IMangoErrors{

    error TransferFailed();
    error BothCantBeZero();
    error NotOwner();
    error EthUnwrapFailed();
    error ValueIsZero();
    error CallDistributeFailed();
    error SwapFailed();
    error AmountExceedsFee();
    error WithdrawalFailed();
    error ReferralFundingFailed();
    
}