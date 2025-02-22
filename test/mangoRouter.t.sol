// SPDX-License-Identifier: UNLICENSED
/** 
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
    MangoRouter00 public mango;
    //IAllowanceTransfer public permit2;
    address public loaner;

    address public weth;
    address public brett;
    address public usdc;

    function setUp() public {
        
        mango = new MangoRouter01();
        weth = 0x4200000000000000000000000000000000000006;
        cheatCodes = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        deal(address(this),1e18);
        assertEq(address(this).balance, 1e18);
        //permit2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        brett = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
        usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        //initiate prank to tranfer some brett to test
        loaner = 0x9BA188E4B2C46C15450EA5Eac83A048E5E5D9444;//0xBA3F945812a83471d709BCe9C3CA699A19FB46f7; weth
        uint256 balance = IERC20(brett).balanceOf(loaner);
        cheatCodes.prank(loaner);
        IERC20(brett).approve(address(this),type(uint256).max);
        bool s = IERC20(brett).transferFrom(loaner,address(this),balance);
        require(s);        
    } 
    function test_swapEthtoTokensv3() public {
        console.log('eth balance before swap',address(this).balance);
        console.log('brettAmount before swzap',IERC20(brett).balanceOf(address(this)));
        mango.ethToTokensV3{
            value:address(this).balance
            }(brett,500);
        uint256 tokenBalance = IERC20(brett).balanceOf(address(this));
        console.log('brettAmount after swap',tokenBalance);
        console.log('eth balance after swap',address(this).balance);
        console.log('fee collected',address(mango).balance);
    }
    function test_ethToTokensV3Revert_msg_ValueZero() public {
        vm.expectRevert(bytes(""));
        mango.ethToTokensV3{
            value:0
            }(brett,500);
    }
    function test_ethToTokensV3Revert_fee_zero() public {
        vm.expectRevert(bytes(""));
        mango.ethToTokensV3{
            value:address(this).balance
            }(brett,0);
    }
    function test_tokenForTokensV3() public {
        console.log('brett amount before swap',IERC20(brett).balanceOf(address(this)));
        uint256 balance = IERC20(brett).balanceOf(address(this));
        IERC20(brett).approve(address(mango),balance);
        mango.tokensForTokensV3(brett,usdc,balance,10000);
        uint256 tokenBalance = IERC20(weth).balanceOf(address(this));
        console.log('brettAmount after swap',tokenBalance);
        console.log('usdc balance->next swap usdc to brett', IERC20(usdc).balanceOf(address(this)));

        IERC20(usdc).approve(address(mango),IERC20(address(usdc)).balanceOf(address(this)));
        mango.tokensForTokensV3(usdc,brett,IERC20(usdc).balanceOf(address(this)),10000);
        console.log('fee collected on usdc swap',IERC20(address(usdc)).balanceOf(address(mango)));
    }
    function test_ethToTokensV2() public {
        uint256 balance = address(this).balance;
        console.log('balance of eth before swap',balance);
        mango.ethToTokensV2{value:address(this).balance}(address(brett));
        console.log('balance eth after swap',address(this).balance);
        console.log('brett balance',IERC20(brett).balanceOf(address(this)));
        console.log('fee collected',address(mango).balance);
    }
    function test_tokenForTokensV2() public {
        console.log('brett balance',IERC20(brett).balanceOf(address(this)));
        uint256 brettBalance = IERC20(brett).balanceOf(address(this));
        IERC20(brett).approve(address(mango),brettBalance);
        mango.tokenToTokenV2_fee_usdc(brett,weth,brettBalance);
        console.log('brett balance after swap',IERC20(brett).balanceOf(address(this)));

        IERC20(usdc).approve(address(mango),IERC20(address(usdc)).balanceOf(address(this)));
        mango.tokenToTokenV2_fee_usdc(usdc,brett,IERC20(address(usdc)).balanceOf(address(this)));
        console.log('fee collected on usdc swap',IERC20(address(usdc)).balanceOf(address(mango)));

    }
    function test_withdrawalOfFees()public{
        uint256 balance = address(this).balance;
        console.log('balance of eth before swap',balance);
        mango.ethToTokensV2{value:address(this).balance}(address(brett));
        console.log('balance eth after swap',address(this).balance);
        console.log('fee collected',address(mango).balance);
        uint256 feeCollected = mango.withdrawEth();
        console.log('s withdrawal, fee collected',feeCollected);

    }
    function test_changeOwner() public {
        
    }
    fallback() external payable{}
}
*/