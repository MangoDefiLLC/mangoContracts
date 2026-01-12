// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MANGO_DEFI_TOKEN} from "../contracts/mangoToken.sol";
import {MangoRouter002} from "../contracts/mangoRouter001.sol";
import {MangoReferral} from "../contracts/mangoReferral.sol";
import {Mango_Manager} from "../contracts/manager.sol";
import {Airdrop} from "../contracts/airDrop.sol";
import {IMangoStructs} from "../contracts/interfaces/IMangoStructs.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TestAllContracts
 * @notice Comprehensive test script for all Mango DeFi contracts
 * @dev This script tests deployment, initialization, and basic functionality of all contracts
 * @custom:usage Run with: forge script script/TestAllContracts.s.sol:TestAllContracts --fork-url <RPC_URL> -vvvv
 */
contract TestAllContracts is Script {
    // Contract instances
    MANGO_DEFI_TOKEN public mangoToken;
    MangoRouter002 public mangoRouter;
    MangoReferral public mangoReferral;
    Mango_Manager public manager;
    // Presale contract removed from this repo; related tests were deleted
    Airdrop public airdrop;

    // Deployment addresses (will be set based on chain or provided via env)
    address public factoryV2;
    address public factoryV3;
    address public routerV2;
    address public swapRouter02;
    address public weth;
    
    // Test addresses
    address public deployer;
    address public testUser = address(0x1234);
    address public testPair = address(0x5678);
    address public testV3Pool = address(0x9ABC);

    function setUp() public {
        deployer = msg.sender;
        
        // Try to load from environment, fallback to test addresses
        factoryV2 = vm.envOr("FACTORY_V2", address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f)); // Uniswap V2 Factory
        factoryV3 = vm.envOr("FACTORY_V3", address(0x1F98431c8aD98523631AE4a59f267346ea31F984)); // Uniswap V3 Factory
        routerV2 = vm.envOr("ROUTER_V2", address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)); // Uniswap V2 Router
        swapRouter02 = vm.envOr("SWAP_ROUTER_02", address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45)); // Uniswap V3 Router
        weth = vm.envOr("WETH", address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)); // WETH
    }

    function run() public {
        console.log("==========================================");
        console.log("Mango Contracts Test Suite");
        console.log("==========================================");
        console.log("Deployer:", deployer);
        console.log("");

        vm.startBroadcast();

        // Test 1: Deploy Mango Token
        console.log("Test 1: Deploying MANGO_DEFI_TOKEN...");
        testDeployMangoToken();
        console.log("OK:  Mango Token deployed successfully");
        console.log("");

        // Test 2: Deploy Mango Router
        console.log("Test 2: Deploying MangoRouter002...");
        testDeployMangoRouter();
        console.log("OK:  Mango Router deployed successfully");
        console.log("");

        // Test 3: Deploy Mango Referral
        console.log("Test 3: Deploying MangoReferral...");
        testDeployMangoReferral();
        console.log("OK:  Mango Referral deployed successfully");
        console.log("");

        // Test 4: Deploy Manager
        console.log("Test 4: Deploying Mango_Manager...");
        testDeployManager();
        console.log("OK:  Manager deployed successfully");
        console.log("");


        // Test 7: Basic Functionality Tests
        console.log("Test 7: Testing Basic Functionality...");
        testBasicFunctionality();
        console.log("OK:  Basic functionality tests passed");
        console.log("");

        // Test 8: Contract Integration Tests
        console.log("Test 8: Testing Contract Integration...");
        testContractIntegration();
        console.log("OK:  Contract integration tests passed");
        console.log("");

        vm.stopBroadcast();

        console.log("==========================================");
        console.log("All Tests Passed Successfully!");
        console.log("==========================================");
        console.log("Deployed Contracts:");
        console.log("  Mango Token:", address(mangoToken));
        console.log("  Mango Router:", address(mangoRouter));
        console.log("  Mango Referral:", address(mangoReferral));
        console.log("  Manager:", address(manager));
    // Presale removed
        console.log("  Airdrop:", address(airdrop));
    }

    function testDeployMangoToken() internal {
        IMangoStructs.cTokenParams memory tokenParams = IMangoStructs.cTokenParams({
            manager: address(0), // Will be set after manager deployment
            uniswapRouterV2: routerV2,
            uniswapRouterV3: address(0),
            uniswapV3Factory: factoryV3
        });

        mangoToken = new MANGO_DEFI_TOKEN(tokenParams);
        
        // Verify deployment
        require(address(mangoToken) != address(0), "Token deployment failed");
        require(mangoToken.owner() == deployer, "Token owner incorrect");
        require(mangoToken.totalSupply() == 100000000000e18, "Token supply incorrect");
        require(mangoToken.taxWallet() == deployer, "Tax wallet incorrect");
        
        console.log("  Address:", address(mangoToken));
        console.log("  Total Supply:", mangoToken.totalSupply());
        console.log("  Owner:", mangoToken.owner());
    }

    function testDeployMangoRouter() internal {
        IMangoStructs.cParamsRouter memory routerParams = IMangoStructs.cParamsRouter({
            factoryV2: factoryV2,
            factoryV3: factoryV3,
            routerV2: routerV2,
            swapRouter02: swapRouter02,
            weth: weth,
            taxFee: 300, // 3%
            referralFee: 100 // 1%
        });

        mangoRouter = new MangoRouter002(routerParams);
        
        // Verify deployment
        require(address(mangoRouter) != address(0), "Router deployment failed");
        require(mangoRouter.owner() == deployer, "Router owner incorrect");
        require(mangoRouter.taxFee() == 300, "Tax fee incorrect");
        require(mangoRouter.referralFee() == 100, "Referral fee incorrect");
        require(mangoRouter.taxMan() == deployer, "Tax man incorrect");
        
        console.log("  Address:", address(mangoRouter));
        console.log("  Tax Fee:", mangoRouter.taxFee());
        console.log("  Referral Fee:", mangoRouter.referralFee());
        console.log("  Tax Man:", mangoRouter.taxMan());
    }

    function testDeployMangoReferral() internal {
        IMangoStructs.cReferralParams memory referralParams = IMangoStructs.cReferralParams({
            mangoRouter: address(mangoRouter),
            mangoToken: address(mangoToken),
            routerV2: routerV2,
            weth: weth
        });

        mangoReferral = new MangoReferral(referralParams);
        
        // Verify deployment
        require(address(mangoReferral) != address(0), "Referral deployment failed");
        require(mangoReferral.owner() == deployer, "Referral owner incorrect");
        require(address(mangoReferral.mangoToken()) == address(mangoToken), "Token address incorrect");
        require(mangoReferral.whiteListed(address(mangoRouter)), "Router not whitelisted");
        
        console.log("  Address:", address(mangoReferral));
        console.log("  Owner:", mangoReferral.owner());
        console.log("  Mango Token:", address(mangoReferral.mangoToken()));
    }

    function testDeployManager() internal {
        IMangoStructs.cManagerParams memory managerParams = IMangoStructs.cManagerParams({
            mangoRouter: address(mangoRouter),
            mangoReferral: address(mangoReferral),
            token: address(mangoToken)
        });

        manager = new Mango_Manager(managerParams);
        
        // Verify deployment
        require(address(manager) != address(0), "Manager deployment failed");
        require(manager.owner() == deployer, "Manager owner incorrect");
        require(address(manager.mangoRouter()) == address(mangoRouter), "Router address incorrect");
        require(address(manager.mangoReferral()) == address(mangoReferral), "Referral address incorrect");
        require(address(manager.mangoToken()) == address(mangoToken), "Token address incorrect");
        
        console.log("  Address:", address(manager));
        console.log("  Owner:", manager.owner());
        console.log("  Router:", address(manager.mangoRouter()));
        console.log("  Referral:", address(manager.mangoReferral()));
    }

    function testBasicFunctionality() internal {
        // Test Mango Token functions
        console.log("  Testing Mango Token...");
        mangoToken.addPair(testPair);
        require(mangoToken.isPair(testPair), "Pair not added");
        mangoToken.addV3Pool(testV3Pool);
        require(mangoToken.isV3Pool(testV3Pool), "V3 Pool not added");
        mangoToken.excludeAddress(testUser);
        require(mangoToken.isExcludedFromTax(testUser), "User not excluded");
        console.log("    OK:  Mango Token functions work");

        // Test Router functions
        console.log("  Testing Mango Router...");
        address newTaxMan = address(0x9999);
        mangoRouter.changeTaxMan(newTaxMan);
        require(mangoRouter.taxMan() == newTaxMan, "Tax man not updated");
        mangoRouter.setReferralContract(address(mangoReferral));
        require(address(mangoRouter.mangoReferral()) == address(mangoReferral), "Referral not set");
        console.log("    OK:  Router functions work");

        // Test Referral functions
        console.log("  Testing Mango Referral...");
        address newRouter = address(0x8888);
        mangoReferral.addRouter(newRouter);
        require(mangoReferral.whiteListed(newRouter), "Router not whitelisted");
        mangoReferral.addReferralChain(testUser, deployer);
        require(mangoReferral.getReferralChain(testUser) == deployer, "Referral chain not set");
        console.log("    OK:  Referral functions work");

    // Presale contract removed - skipping presale functional tests

        // Test Airdrop functions
        console.log("  Testing Airdrop...");
        airdrop.addToWhitelist(testUser);
        require(airdrop.whiteList(testUser), "User not whitelisted");
        airdrop.removeFromWhitelist(testUser);
        require(!airdrop.whiteList(testUser), "User should not be whitelisted");
        console.log("    OK:  Airdrop functions work");
    }

    function testContractIntegration() internal {
        console.log("  Testing contract integration...");
        
        // Test: Manager receives fees
        console.log("    Testing Manager fee receiving...");
        // to add fee to manager just send eth
        uint256 feeAmount = 1 ether;
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success, "Fee transfer failed");
        require(manager.totalFeesCollected() == feeAmount, "Total fees incorrect");
        console.log("      OK:  Manager receives fees correctly");

        // Test: Router referral integration
        console.log("    Testing Router-Referral integration...");
        require(address(mangoRouter.mangoReferral()) == address(mangoReferral), "Router referral not set");
        console.log("      OK:  Router-Referral integration correct");

        // Test: Token router integration (set manager as tax wallet)
        console.log("    Testing Token-Manager integration...");
        mangoToken.setTaxWallet(address(manager));
        require(mangoToken.taxWallet() == address(manager), "Tax wallet not set");
        console.log("      OK:  Token-Manager integration correct");

    // Presale removed - skipping presale-referral integration test
    }
}

