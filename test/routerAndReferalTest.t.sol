// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IMangoRouter} from '../contracts/interfaces/IMangoRouter.sol';
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
    address public b4 = 0xb4d0bd19178EA860D5AefCdEfEab7fcFE9D8EF17;
    address public tester0 = address(0x10);
    address public add1 = address(0x01);
    address public add2 = address(0x02);
    address public add3 = address(0x03);
    address public add4 = address(0x0FB602E2E1eE587d9c0Da6368E352E33bfEcF12e);
    address public add5 = address(0x05);

    address public weth;
    address public brett;
    address public usdt;
    address public cake;

    function setUp() public {
        //contracts deployment order
        //router
        //token
        //referal
        mangoRouter = new MangoRouter002();//0xeE629d83e42564A17Ea50E34c2D2A121d5A6E911);
        weth = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;//wbnb
        cake = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
        usdt = 0x55d398326f99059fF775485246999027B3197955;

        cheatCodes = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cheatCodes.prank(0xF977814e90dA44bFA03b6295A0616a897441aceC);
        //IERC20(usdc).approve(address(this),20e6);
        IERC20(usdt).transfer(address(this),20e6);


        //deply referal to test it works
        //mangoReferal = new MangoReferral(address(this),address(mangoRouter));//owner and router
    
        }
    function test_swap() public {
        uint256 ethBalanceBeforeSwap = address(this).balance;
        console.log(ethBalanceBeforeSwap ,'WBNB balence before swap');
        //console.log(IERC20(usdt).balanceOf(address(this)),'usdc balance of swapper before swap');
    
    // IERC20(usdt).approve(address(mangoRouter),IERC20(usdt).balanceOf(address(this)));
        mangoRouter.swap{value:ethBalanceBeforeSwap}(address(0),cake,0,address(0));
        console.log(address(this).balance,'WBNB balence after swap');
        assertNotEq(ethBalanceBeforeSwap, address(this).balance);
        
    }
    //     function test_SwapAndDistribute_floor1_ethToTOken() external{
    //         (bool s,) = add1.call{value:1e18}("");
    //         uint256 ethBalanceBeforeSwap = address(this).balance;
    //         console.log(add1.balance,'eth balance of add 1 before swap');
    //          console.log(mangoToken.balanceOf(add1),'$MANGO balance before of referrer0');

    //         console.log(IERC20(usdc).balanceOf(address(this)),'usdc balance of swapper before swap');

    //         mangoRouter.swap{value:amount}(address(0),usdc,0,add1);

    //         console.log(IERC20(usdc).balanceOf(address(this)),'usdc balance of swapper after swap');

    //         assertNotEq(ethBalanceBeforeSwap,address(this).balance,'balance are the same, swap failed');
    //         uint256 ethBalanceAfterSwap = address(this).balance;
    //         assertEq(ethBalanceAfterSwap, amount * 300 / 10000,'balance after swap is not %3');
            
    //         console.log(mangoToken.balanceOf(add1),'$MANGO balance of referrer0');
    //         assertNotEq(mangoToken.balanceOf(add1),0);

    // }
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
    fallback() external payable {}
}