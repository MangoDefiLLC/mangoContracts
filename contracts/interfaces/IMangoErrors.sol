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
    error InvalidSwapPath();
    
    // New custom errors for string error replacements (GAS-02)
    error PresaleEnded();
    error InvalidAmount();
    error AmountExceedsMaxBuy();
    error PriceNotSet();
    error ETHTransferFailed();
    error NotAuthorized();
    error CannotReferYourself();
    error PriceOracleUnavailable();
    error ETHNotAccepted();
    error NoPathFound();
    error DirectETHDepositsNotAllowed();
    error InvalidPrice();
    error InvalidAddress();
    error InsufficientBalance();
    
}