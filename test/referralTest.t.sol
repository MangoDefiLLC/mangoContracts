// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IMangoRouter} from '../contracts/interfaces/IMangoRouter.sol';
import {MangoRouter002} from "../contracts/mangoRouter001.sol";
import {MANGO_DEFI_TOKEN} from "../contracts/mangoToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MangoReferral} from '../contracts/mangoReferral.sol';
//import {IAllowanceTransfer} from '../permit2/src/interfaces/IAllowanceTransfer.sol';
interface CheatCodes {
           function prank(address) external;    
 }
 contract Referral_TEST is Test {
    CheatCodes public cheatCodes;
    IMangoRouter public mangoRouter;
    MANGO_DEFI_TOKEN public mangoToken;
    MangoReferral public  mangoReferral;
    uint256 public amount;
    address public mango;
    address public seller;
    //IAllowanceTransfer public permit2;
 }