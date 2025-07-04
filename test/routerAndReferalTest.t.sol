// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MangoRouter002} from "../contracts/mangoRouter001.sol";
import {MANGO_DEFI} from "../contracts/mangoToken.sol";
import{IERC20} from '../contracts/interfaces/IERC20.sol';
import {MangoReferral} from '../contracts/mangoReferral.sol';
//import {IAllowanceTransfer} from '../permit2/src/interfaces/IAllowanceTransfer.sol';
interface CheatCodes {
           function prank(address) external;    
 }
contract test_Router_and_Referal is Test {
    CheatCodes public cheatCodes;
    MangoRouter002 public mangoRouter;
    MANGO_DEFI public mangoToken;
    MangoReferral public  mangoReferral;
    uint256 public amount;
    //IAllowanceTransfer public permit2;
    address public loaner;
    address public tester0 = address(0x10);
    address public add1 = address(0x01);
    address public add2 = address(0x02);
    address public add3 = address(0x03);
    address public add4 = address(0x04);
    address public add5 = address(0x05);

    address public weth;
    address public brett;
    address public usdc;

    function setUp() public {
        //contracts deployment order
        //router
        //token
        //referal
        mangoRouter = new MangoRouter002();
        weth = 0x4200000000000000000000000000000000000006;//weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        cheatCodes = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        mangoToken = new MANGO_DEFI(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24,address(this));
        //deposite mango token on referal
        mangoReferral = new MangoReferral(address(this),address(mangoRouter),address(mangoToken));
        mangoRouter.setReferralContract(address(mangoReferral));
        mangoToken.approve(address(mangoReferral),type(uint256).max);
        mangoReferral.depositeTokens(address(mangoToken), 300000000e18);//300 million
        deal(address(this),2e18); // sepolia usdc = 0x8BEbFCBe5468F146533C182dF3DFbF5ff9BE00E2;
        assertEq(address(this).balance, 2e18);
        deal(add1,2e18);
        deal(add2,2e18);
        deal(add3,2e18);
        deal(add4,2e18);
        deal(add5,2e18);
        amount = 1e18;
        //permit2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        //deply referal to test it works
        //mangoReferal = new MangoReferral(address(this),address(mangoRouter));//owner and router
    
        }
        function test_SwapAndDistribute_floor1_ethToTOken() external{
            (bool s,) = add1.call{value:1e18}("");
            uint256 ethBalanceBeforeSwap = address(this).balance;
            console.log(add1.balance,'eth balance of add 1 before swap');
             console.log(mangoToken.balanceOf(add1),'$MANGO balance before of referrer0');

            console.log(IERC20(usdc).balanceOf(address(this)),'usdc balance of swapper before swap');

            mangoRouter.swap{value:amount}(address(0),usdc,0,add1);

            console.log(IERC20(usdc).balanceOf(address(this)),'usdc balance of swapper after swap');

            assertNotEq(ethBalanceBeforeSwap,address(this).balance,'balance are the same, swap failed');
            uint256 ethBalanceAfterSwap = address(this).balance;
            assertEq(ethBalanceAfterSwap, amount * 300 / 10000,'balance after swap is not %3');
            
            console.log(mangoToken.balanceOf(add1),'$MANGO balance of referrer0');
            assertNotEq(mangoToken.balanceOf(add1),0);

    }
    // function test_buttingReferrer() external {
    //     // tester will refer add1
    //     //then add 1 will try to swap with new referrer
    //     //tester should still get the tokens

    //     assertEq(IERC20(mangoToken).balanceOf(tester0),0);  
    //     console.log('tester0 $mango balance',mangoToken.balanceOf(tester0));     
    //     assertEq(IERC20(mangoToken).balanceOf(add1),0);
    //     assertEq(IERC20(mangoToken).balanceOf(add2),0);

    //     //add1 makes swap adding tester floor1
    //     cheatCodes.prank(add1);
    //     mangoRouter.swap{value:amount}(address(0),usdc,0,tester0);
    //     uint256 tester0balance = IERC20(mangoToken).balanceOf(tester0);
    //     assertNotEq(tester0balance,0);

    //      console.log('tester0 $mango balance',mangoToken.balanceOf(tester0));   

    //     //make another tx with other referrer
    //     cheatCodes.prank(add1);
    //     mangoRouter.swap{value:amount}(address(0),usdc,0,add2);

    //     console.log('tester0 $mango balance',mangoToken.balanceOf(tester0));   
    //     uint256 tester0balance1 = IERC20(mangoToken).balanceOf(tester0);
    //     //assertNotEq(tester0balance1,tester0balance);

    //     console.log(tester0balance1,'tester balance of mango after referree swap');
    //     assertEq(IERC20(mangoToken).balanceOf(add2),0);
    // }
    //  function test_SwapAndDistribute_floor5_ethToTOken() external{

    //     uint256 testerBalance0 = IERC20(mangoToken).balanceOf(tester0);
    //     uint256 add1Balance0 = IERC20(mangoToken).balanceOf(add1);
    //     uint256 add2Balance0 = IERC20(mangoToken).balanceOf(add2);
    //     uint256 add3Balance0 = IERC20(mangoToken).balanceOf(add3);
    //     uint256 add4Balance0 = IERC20(mangoToken).balanceOf(add4);
    //     uint256 add5Balance0 = IERC20(mangoToken).balanceOf(add5);
    //     assertEq(IERC20(mangoToken).balanceOf(add1),0);
    //     assertEq(IERC20(mangoToken).balanceOf(add2),0);
    //     assertEq(IERC20(mangoToken).balanceOf(add3),0);
    //     assertEq(IERC20(mangoToken).balanceOf(add4),0);
    //     assertEq(IERC20(mangoToken).balanceOf(add5),0);

    //     //add1 makes swap adding tester floor1
    //     cheatCodes.prank(add1);
    //     mangoRouter.swap{value:amount}(address(0),usdc,0,tester0);
    //     //make sure add1 is getting pay
    //     uint256 testerBalance1 = IERC20(mangoToken).balanceOf(tester0);
    //     assertNotEq(testerBalance0,testerBalance1);
        
    //     //add1 makes swap adding tester floor1
    //     cheatCodes.prank(add2);
    //     mangoRouter.swap{value:amount}(address(0),usdc,0,add1);
    //     //make sure add1 is getting pay
    //     uint256 testerBalance2 = IERC20(mangoToken).balanceOf(tester0);
    //     assertNotEq(testerBalance1,testerBalance2);

    //     cheatCodes.prank(add3);
    //     mangoRouter.swap{value:amount}(address(0),usdc,0,add2);
    //     //make sure add1 is getting pay
    //    uint256 testerBalance3 = IERC20(mangoToken).balanceOf(tester0);
    //     assertNotEq(testerBalance2,testerBalance3);

    //     cheatCodes.prank(add4);
    //     mangoRouter.swap{value:amount}(address(0),usdc,0,add3);
    //     uint256 testerBalance4 = IERC20(mangoToken).balanceOf(tester0);
    //     assertNotEq(testerBalance3,testerBalance4);

    //     cheatCodes.prank(add5);
    //     mangoRouter.swap{value:amount}(address(0),usdc,0,add4);
    //     uint256 testerBalance5 = IERC20(mangoToken).balanceOf(tester0);
    //     assertNotEq(testerBalance4,testerBalance5);
    // }
    // function test_nonRouterCallDistribute_expectRevert() external {
    //     vm.expectRevert("only mango routers can call Distribution");
    //     vm.prank(add1);
    //     mangoReferral.distributeReferralRewards(add1,1e18,tester0);
    // }
    // function test_swap() public {
    //     uint256 ethBalanceBeforeSwap = address(this).balance;
    //     console.log(add1.balance,'balance of add 1 before swap');
    //     console.log(IERC20(usdc).balanceOf(address(this)),'usdc balance of swapper before swap');
    //     mangoRouter.swap{value:amount}(address(0),usdc,0,address(0));
    //     console.log(IERC20(usdc).balanceOf(address(this)),'usdc balance of swapper after swap');
    //     assertNotEq(ethBalanceBeforeSwap,address(this).balance,'balance are the same, swap failed');
    //     uint256 ethBalanceAfterSwap = address(this).balance;
    //     assertEq(ethBalanceAfterSwap, amount * 300 / 10000,'balance after swap is not %3');
        
    // }
    fallback() external payable {}
}