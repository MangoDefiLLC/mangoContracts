// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MangoRouter001} from "../contracts/mangoRouter001.sol";
import{IERC20} from '../contracts/interfaces/IERC20.sol';
//import {IAllowanceTransfer} from '../permit2/src/interfaces/IAllowanceTransfer.sol';
interface CheatCodes {
           function prank(address) external;    
 }
contract CounterTest is Test {
    CheatCodes public cheatCodes;
    MangoRouter001 public mango;

    //IAllowanceTransfer public permit2;
    address public loaner;

    address public weth;
    address cointentLoaner;
    address public brett;
    address public usdc;
    address public cointent;
    struct Path {
        address poolAddress;
        uint24 poolFee;
    }
    event Deposit(uint256);

    function setUp() public {
        
        mango = new MangoRouter001();
        weth = 0x4200000000000000000000000000000000000006;
        cheatCodes = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cointent = 0x0cb66A7127605377796a48F2F66b71AbD14eedA4;
        deal(address(this),1e18);
        assertEq(address(this).balance, 1e18);
        //permit2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        brett = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
        usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        //initiate prank to tranfer some brett to test
        loaner = 0x9BA188E4B2C46C15450EA5Eac83A048E5E5D9444;//0xBA3F945812a83471d709BCe9C3CA699A19FB46f7; weth
        cointentLoaner = 0xb4d0bd19178EA860D5AefCdEfEab7fcFE9D8EF17;
        uint256 balance = IERC20(brett).balanceOf(loaner);
        cheatCodes.prank(loaner);
        IERC20(brett).approve(address(this),type(uint256).max);
        bool s = IERC20(brett).transferFrom(loaner,address(this),balance);
        require(s);
        cheatCodes.prank(cointentLoaner);
        bool _s = IERC20(cointent).approve(address(this),type(uint256).max);
        require(_s,'approve failed');
        IERC20(cointent).transferFrom(cointentLoaner,address(this),IERC20(cointent).balanceOf(cointentLoaner));      
    }
  
    // function test_swapEthToTokenV2() public {
    //     uint256 ethB0 = address(this).balance;
    //     console.log(ethB0);
    //     uint256 brettB0 = IERC20(brett).balanceOf(address(this));
    //     console.log('brett before',brettB0);
    //     //IERC20(cointent).approve(address(mango),type(uint256).max);
    //    // console.log('approving, no calling swap',address(this));

    //     mango.swap{value:1e18}(address(0),brett,0);
    //     uint256 brettB1 = IERC20(brett).balanceOf(address(this));
    //     console.log('brett after',brettB1);
    //     uint256 ethB1 = address(this).balance;
    //     console.log('fee collected eth balance after',ethB1);
    //     assertNotEq(brettB0,brettB1,'value are the same before and after swap');
    //     assertNotEq(ethB0,ethB1,'amount of eth are equal');
    // }
    //  function test_swapethToTokenV3() public {
    //      uint256 ethB0 = address(this).balance;
    //      console.log(ethB0);
    //     uint256 cointentB0 = IERC20(cointent).balanceOf(address(this));
    //     console.log('cointent before',cointentB0);
    //     IERC20(cointent).approve(address(mango),type(uint256).max);
    //    console.log('approving, no calling swap',address(this));

    //     mango.swap{value:address(this).balance}(address(0),cointent,0);
    //     uint256 cointentB1 = IERC20(cointent).balanceOf(address(this));
    //     console.log('cointent after',cointentB1);
    //     uint256 ethB1 = address(this).balance;
    //     console.log('fee collected eth balance after',address(this).balance);
    //     assertNotEq(cointentB0,cointentB1,'value are the same before and after swap');
    //         assertNotEq(ethB0,ethB1,'amount of eth are equal');
    // }
    // function test_tokenToEthV2() public {
    //     uint256 ethB0 = address(this).balance;
       
    //     console.log('eth before',address(this).balance);

    //     uint256 brettB0 = IERC20(brett).balanceOf(address(this));
    //     console.log('bret before',brettB0);

    //     IERC20(brett).approve(address(mango),brettB0);
        
    //     console.log('eth before',address(this).balance);
    //     mango.swap(brett,address(0),brettB0);

    //     uint256 brettB1 = IERC20(brett).balanceOf(address(this));

    //     console.log('bret after',brettB1);
    //     uint256 ethB1 = address(this).balance;
    //     assertNotEq(brettB0,brettB1,'value are the same before and after swap');
    //     assertNotEq(ethB0,ethB1,'eth amount are equal');
    // }
    // function test_tokenToEthV3() public {

    //     console.log(address(this).balance);
    //      uint256 ethB0 = address(this).balance;
    //     uint256 cointentB1 = IERC20(cointent).balanceOf(address(this));
    //     IERC20(cointent).approve(address(mango),cointentB1);

    //     //sell cointent for eth
    //     mango.swap(cointent,address(0),cointentB1);
    //     uint256 ethB1 = address(this).balance;
    //     assertNotEq(cointentB1,IERC20(cointent).balanceOf(address(this)));
    //     assertNotEq(ethB0,ethB1,'eth amount are equal');
    // }
    function test_tokenToTokenV2() public{
        uint256 brettB0 = IERC20(brett).balanceOf(address(this));
        uint256 usdcB0 = IERC20(usdc).balanceOf(address(this));
        console.log('bret before',brettB0);
        IERC20(brett).approve(address(mango),brettB0);
        mango.swap(brett,usdc,brettB0);
        uint256 brettB1 = IERC20(brett).balanceOf(address(this));
        uint256 usdcB1 = IERC20(usdc).balanceOf(address(this));
        console.log('bret before',brettB0);
        assertNotEq(usdcB0,usdcB1,'usdc amount aqueal after swap');
        assertNotEq(brettB0,brettB1,'brett amount aqueal after swap');
    }
    function test_expectRevert_both_zero_address() public{
        
        mango.swap{value:1e18}(address(0),address(0),0);
        //vm.expectRevert('');
    }
    function test_expectRevert_amounts_cantBeZero() public{
        mango.swap{value:0}(weth,brett,0);
    }
  
    fallback() external payable{
        emit Deposit(msg.value);
    }
   
}
