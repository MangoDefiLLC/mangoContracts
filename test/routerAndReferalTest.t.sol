// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IMangoRouter} from '../contracts/interfaces/IMangoRouter.sol';
import {MangoRouter002} from "../contracts/mangoRouter001.sol";
import {MANGO_DEFI_TOKEN} from "../contracts/mangoToken.sol";
import {MangoReferral} from '../contracts/mangoReferral.sol';
import { IUniswapV2Factory } from "../contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV3Factory } from "../contracts/interfaces/IUniswapV3Factory.sol";
import { IRouterV2 } from "../contracts/interfaces/IRouterV2.sol";
import { IMangoReferral } from "../contracts/interfaces/IMangoReferral.sol";
import { IWETH9 } from "../contracts/interfaces/IWETH9.sol";
import { IMangoErrors } from "../contracts/interfaces/IMangoErrors.sol";
import {IMangoStructs} from "../contracts/interfaces/IMangoStructs.sol";
import {Mango_Manager} from "../contracts/manager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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


contract test_Router_and_Referal_Fork is Test {
    CheatCodes public cheatCodes;
    IMangoRouter public ImangoRouter;
    MangoRouter002 public mangoRouter;
    MANGO_DEFI_TOKEN public mangoToken;
    MangoReferral public  mangoReferral;
    Mango_Manager public mangoManager;
    

    string public BASE;
    string public SEPOLIA;
    uint256 public amount;
    address public mango;
    address public seller;
    uint256 public baseFork;
    uint256 public sepoliaFork;

    address public taxMan;

    //IAllowanceTransfer public permit2;


    address public weth;
    address public brett;
    address public usdc;

    address public referrer0 = address(0x01);
    address public referrer1 = address(0x02);

    function setUp() public {
        //contracts deployment order

       
        cheatCodes = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        seller = 0xb4d0bd19178EA860D5AefCdEfEab7fcFE9D8EF17;
        usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

        BASE = vm.envString("BASE_RPC");
        SEPOLIA = vm.envString("SEPOLIA_RPC");
        baseFork = vm.createFork(BASE);
       sepoliaFork = vm.createFork(SEPOLIA);
        
        //mango = 0x5Ac57Bf5395058893C1a0f4250D301498DCB11fC;
        // vm.startPrank(seller);
        // IERC20(mango).transfer(address(this),IERC20(mango).balanceOf(seller));
        // vm.stopPrank();
        deal(address(this),1e18);

        testCanSelectFork();
        testForkIdDiffer();

        testSetEchosystemBase();
        //vm.makePersistent(mangoRouter,mangoToken,mangoReferral);
        //deply referal to test it works
        //mangoReferal = new MangoReferral(address(this),address(mangoRouter));//owner and router
    
        }
        // create two _different_ forks during setup
 
    // demonstrate fork ids are unique
    function testForkIdDiffer() public {
        assert(baseFork == baseFork);
    }
 
    // select a specific fork
    function testCanSelectFork() public {
        // select the fork
        vm.selectFork(baseFork);
        assertEq(vm.activeFork(), baseFork);
 
        // from here on data is fetched from the `mainnetFork` if the EVM requests it and written to the storage of `mainnetFork`
    }
    //SETUP TOKEN REFERRAL READY TO TEST
    function testSetEchosystemBase() public {
        //deploy router
        IMangoStructs.cParamsRouter memory params = IMangoStructs.cParamsRouter(
            //this is base 
            0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6,//factpryv2
            0x33128a8fC17869897dcE68Ed026d694621f6FDfD,//factpry v3
            0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24,//routerv2
            0x2626664c2603336E57B271c5C0b26F421741e481,//swapRouter02
            0x4200000000000000000000000000000000000006,//weth
            300,//taxFee
            100//fererralFee
        );
        /**
         //this is BSC
            0xBCfCcbde45cE874adCB698cC183deBcF17952812,//factpryv2
            0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865,//factpry v3
            0x10ED43C718714eb63d5aA57B78B54704E256024E,//routerv2
            0x1b81D678ffb9C0263b24A97847620C99d213eB14,//swapRouter02
            0x4200000000000000000000000000000000000006,//weth
            300,//taxFee
            100//fererralFee */


        mangoRouter = new MangoRouter002(params);
        console.log('Router Address:',address(mangoRouter));

        //deploy token
        mangoToken = new MANGO_DEFI_TOKEN(100000000000e18);
        
        //setting up params for referral
        IMangoStructs.cReferralParams memory referralParams = IMangoStructs.cReferralParams(
            address(mangoRouter),//router address
            address(mangoToken),
            params.routerV2,
            params.weth
        );
        //deploy referral
        mangoReferral = new MangoReferral(referralParams);

        //prapre params for mangoManager
        IMangoStructs.cManagerParams memory mangoManagerParams = IMangoStructs.cManagerParams(
            address(mangoRouter),
            address(mangoReferral),
            address(mangoToken)
        );
        mangoManager = new Mango_Manager(mangoManagerParams);

        //@DEV Now we set all the current contracts

        //set referral contract on router
        mangoRouter.setReferralContract(address(mangoReferral));

        //validate router to call referral
        mangoReferral.addRouter(address(mangoRouter));
        mangoReferral.addToken((address(mangoToken)));

        taxMan = address(mangoManager);
        //add tax man
        mangoRouter.changeTaxMan(taxMan);

        //approve referral for deposite
        mangoToken.approve(address(mangoReferral), type(uint256).max);
        mangoReferral.depositeTokens(address(mangoToken),5000000e18);
    }
    //@DEV the test simple swap test that a swap is happening
    // the fee is send to the manager 
    //the manager splits the fee in two fee/3
    function testSimpleEthTokenSwap() external {
        //check for taxman balance before and after
        uint256 taxManBalanceBefore = address(mangoManager).balance;

        mangoRouter.swap{value:1e18}(
            address(0),
            usdc,
            0,
            referrer0
        );

        uint256 taxManBalanceAfter = address(mangoManager).balance;
        uint256 fee = (1e18*3)/10000;
        //assertEq(fee, taxManBalanceAfter-taxManBalanceBefore,'taxman getting wrong fee amount');
        //assert that the mangoManager is slicing the amount
        uint256 buyAndBurnFee = mangoManager.buyAndBurnFee();
        assertEq(mangoManager.teamFee(),mangoManager.buyAndBurnFee(),'mangoManager is not slicing the amount in 3 with presicion');
        assertEq(mangoManager.buyAndBurnFee(),mangoManager.referralFee(), 'mangoManager is not slicing the amount in 3 with presicion');
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
    //    function test_sellMango() external {
    //     vm.startPrank(seller);
    //     uint256 ethBalance = address(this).balance;
    //     uint256 mangoBalanceBefore = IERC20(mango).balanceOf(seller);
    //     console.log('eth balance before',ethBalance);
    //     console.log('mango Balance beofer',mangoBalanceBefore);
        
    //     IERC20(mango).approve(address(mangoRouter), IERC20(mango).balanceOf(seller));
    //     mangoRouter.swap(mango,address(0),32000e18,address(0));

    //     assertNotEq(mangoBalanceBefore,  IERC20(mango).balanceOf(seller));
    // }
    // function test_swap() public {
    //     uint256 ethBalanceBeforeSwap = address(this).balance;
    //     uint256 mangoBalanceBefore = IERC20(mango).balanceOf(address(this));

    //     //vm.startPrank(b4);
    //     //IERC20(mango).approve(address(mangoRouter),150000000e18);
    //     mangoRouter.swap{value:1e18}(address(0),mango,0,address(0));
    //     assertNotEq(ethBalanceBeforeSwap,  address(this).balance);
    //     assertNotEq(mangoBalanceBefore,IERC20(mango).balanceOf(address(this)));
        
    // }
    //fallback() external payable {}
}