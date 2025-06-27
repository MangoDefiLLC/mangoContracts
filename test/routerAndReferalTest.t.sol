// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MangoRouter001} from "../contracts/mangoRouter001.sol";
import {MANGO_DEFI} from "../contracts/mangoToken.sol";
import{IERC20} from '../contracts/interfaces/IERC20.sol';
import {MangoReferral} from '../contracts/mangoReferral.sol';
//import {IAllowanceTransfer} from '../permit2/src/interfaces/IAllowanceTransfer.sol';
interface CheatCodes {
           function prank(address) external;    
 }
contract test_Router_and_Referal is Test {
    CheatCodes public cheatCodes;
    MangoRouter001 public mangoRouter;
    MangoReferral public  mangoReferal;
    //IAllowanceTransfer public permit2;
    address public loaner;
    address public add1 = address(0x01);
    address public add2 = address(0x02);
    address public add3 = address(0x03);
    address public add4 = address(0x04);
    address public add5 = address(0x05);


    address public weth;
    address public brett;
    address public usdc;

    function setUp() public {
        
        mangoRouter = new MangoRouter001();
        weth = 0x4200000000000000000000000000000000000006;//weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        cheatCodes = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        deal(address(this),1e18); // sepolia usdc = 0x8BEbFCBe5468F146533C182dF3DFbF5ff9BE00E2;
        assertEq(address(this).balance, 1e18);
        //permit2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

        //deply referal to test it works
        //mangoReferal = new MangoReferral(address(this),address(mangoRouter));//owner and router
    
        }
    function test_distribute_floor_1() public {
        console.log(add1.balance,'balance of add 1 after swap');
        mangoRouter.swap{value:1e18}(address(0),usdc,0,add1);
        console.log('usdc balance after swap',IERC20(usdc).balanceOf(address(this)));
        console.log(add1.balance,'balance of add 1 after swap');
    }
}