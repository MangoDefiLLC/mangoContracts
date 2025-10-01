// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IMangoRouter} from '../contracts/interfaces/IMangoRouter.sol';
import {MangoRouter002} from "../contracts/mangoRouter001.sol";
import {MANGO_DEFI_TOKEN} from "../contracts/mangoToken.sol";
import{IERC20} from '../contracts/interfaces/IERC20.sol';
import {MangoReferral} from '../contracts/mangoReferral.sol';
import { IUniswapV2Factory } from "../contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV3Factory } from "../contracts/interfaces/IUniswapV3Factory.sol";
import { IRouterV2 } from "../contracts/interfaces/IRouterV2.sol";
import { IMangoReferral } from "../contracts/interfaces/IMangoReferral.sol";
import { IWETH9 } from "../contracts/interfaces/IWETH9.sol";
import { IMangoErrors } from "../contracts/interfaces/IMangoErrors.sol";
//import { ISwapRouter02} from "../contracts/interfaces/ISwapRouter02.sol";
//import {IAllowanceTransfer} from '../permit2/src/interfaces/IAllowanceTransfer.sol';
interface CheatCodes {
           function prank(address) external;    
 }
 interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}

struct cParamsRouter {
        IUniswapV2Factory factoryV2;
        IUniswapV3Factory factoryV3;
        IRouterV2 routerV2;
        ISwapRouter02 swapRouter02;
        IWETH9 weth;
        uint256 taxFee;
        uint256 referralFee;
    }
contract test_Router_and_Referal_Fork is Test {
    CheatCodes public cheatCodes;
    IMangoRouter public mangoRouter;
    MANGO_DEFI_TOKEN public mangoToken;
    MangoReferral public  mangoReferral;

    string public BASE;
    string public SEPOLIA;
    uint256 public amount;
    address public mango;
    address public seller;
    uint256 public baseFork;
    uint256 public sepoliaFork;

    //IAllowanceTransfer public permit2;


    address public weth;
    address public brett;
    address public usdc;

    function setUp() public {
        //contracts deployment order
        //router
        //token
        //referal
        mangoRouter = IMangoRouter(0x59f91E149C435BDf0277A2e9e055345CA989D45D);//0xeE629d83e42564A17Ea50E34c2D2A121d5A6E911);
        weth = 0x4200000000000000000000000000000000000006;
        usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        cheatCodes = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        seller = 0xb4d0bd19178EA860D5AefCdEfEab7fcFE9D8EF17;

        BASE = vm.envString("BASE_RPC");
        SEPOLIA = vm.envString("SEPOLIA_RPC");
        baseFork = vm.createFork(BASE);
        sepoliaFork = vm.createFork(SEPOLIA);
        
        mango = 0x5Ac57Bf5395058893C1a0f4250D301498DCB11fC;
        // vm.startPrank(seller);
        // IERC20(mango).transfer(address(this),IERC20(mango).balanceOf(seller));
        // vm.stopPrank();
        deal(address(this),1e18);


        //deply referal to test it works
        //mangoReferal = new MangoReferral(address(this),address(mangoRouter));//owner and router
    
        }
        // create two _different_ forks during setup
 
    // demonstrate fork ids are unique
    function testForkIdDiffer() public {
        assert(baseFork != sepoliaFork);
    }
 
    // select a specific fork
    function testCanSelectFork() public {
        // select the fork
        vm.selectFork(baseFork);
        assertEq(vm.activeFork(), baseFork);
 
        // from here on data is fetched from the `mainnetFork` if the EVM requests it and written to the storage of `mainnetFork`
    }
    //SETUP TOKEN REFERRAL READY TO TEST
    function setEchosystemBase() public {
        //deploy router
        cParamsRouter memory params = cParamsRouter(
            IUniswapV2Factory(0xBCfCcbde45cE874adCB698cC183deBcF17952812),//factpryv2
            IUniswapV3Factory(0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865),//factpry v3
            IRouterV2(0x10ED43C718714eb63d5aA57B78B54704E256024E),//routerv2
            ISwapRouter02(0x1b81D678ffb9C0263b24A97847620C99d213eB14),//swapRouter02
            IWETH9(0x4200000000000000000000000000000000000006),//weth
            300,//taxFee
            100//fererralFee
        );


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
       function test_sellMango() external {
        vm.startPrank(seller);
        uint256 ethBalance = address(this).balance;
        uint256 mangoBalanceBefore = IERC20(mango).balanceOf(seller);
        console.log('eth balance before',ethBalance);
        console.log('mango Balance beofer',mangoBalanceBefore);
        
        IERC20(mango).approve(address(mangoRouter), IERC20(mango).balanceOf(seller));
        mangoRouter.swap(mango,address(0),32000e18,address(0));

        assertNotEq(mangoBalanceBefore,  IERC20(mango).balanceOf(seller));
    }
    // function test_swap() public {
    //     uint256 ethBalanceBeforeSwap = address(this).balance;
    //     uint256 mangoBalanceBefore = IERC20(mango).balanceOf(address(this));

    //     //vm.startPrank(b4);
    //     //IERC20(mango).approve(address(mangoRouter),150000000e18);
    //     mangoRouter.swap{value:1e18}(address(0),mango,0,address(0));
    //     assertNotEq(ethBalanceBeforeSwap,  address(this).balance);
    //     assertNotEq(mangoBalanceBefore,IERC20(mango).balanceOf(address(this)));
        
    // }
    fallback() external payable {}
}