// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MangoRouter002} from "../contracts/mangoRouter001.sol";
import {MANGO_DEFI_TOKEN} from "../contracts/mangoToken.sol";
import {MangoReferral} from "../contracts/mangoReferral.sol";
import {IMangoStructs} from "../contracts/interfaces/IMangoStructs.sol";
import {IMangoErrors} from "../contracts/interfaces/IMangoErrors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockRouter} from "./mocks/MockRouter.sol";

contract MangoRouterTest is Test {
    MangoRouter002 public router;
    MockERC20 public mockToken;
    MockERC20 public mockWETH;
    MangoReferral public referral;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public taxMan = address(0x3);
    address public factoryV2 = address(0x4);
    address public factoryV3 = address(0x5);
    address public routerV2 = address(0x6);
    address public swapRouter02 = address(0x7);

    function setUp() public {
        vm.startPrank(owner);
        
        mockWETH = new MockERC20("WETH", "WETH", 18);
        mockToken = new MockERC20("TestToken", "TEST", 18);
        
        // Deploy referral
        IMangoStructs.cReferralParams memory refParams = IMangoStructs.cReferralParams({
            mangoRouter: IMangoRouter(address(0)), // Will be set after router deployment
            mangoToken: address(mockToken),
            routerV2: IRouterV2(routerV2),
            weth: address(mockWETH)
        });
        referral = new MangoReferral(refParams);
        
        // Deploy router
        IMangoStructs.cParamsRouter memory params = IMangoStructs.cParamsRouter({
            factoryV2: factoryV2,
            factoryV3: factoryV3,
            routerV2: routerV2,
            swapRouter02: swapRouter02,
            weth: address(mockWETH),
            taxFee: 300, // 3%
            referralFee: 100 // 1%
        });
        router = new MangoRouter002(params);
        router.changeTaxMan(taxMan);
        
        vm.stopPrank();
    }

    // ============ Constructor Tests ============

    function test_Constructor_Success() public {
        assertEq(router.owner(), owner);
        assertEq(address(router.factoryV2()), factoryV2);
        assertEq(address(router.factoryV3()), factoryV3);
        assertEq(address(router.routerV2()), routerV2);
        assertEq(address(router.swapRouter02()), swapRouter02);
        assertEq(address(router.weth()), address(mockWETH));
        assertEq(router.taxFee(), 300);
        assertEq(router.referralFee(), 100);
    }

    function test_Constructor_Revert_ZeroFactoryV2() public {
        IMangoStructs.cParamsRouter memory params = IMangoStructs.cParamsRouter({
            factoryV2: address(0),
            factoryV3: factoryV3,
            routerV2: routerV2,
            swapRouter02: swapRouter02,
            weth: address(mockWETH),
            taxFee: 300,
            referralFee: 100
        });
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        new MangoRouter002(params);
    }

    function test_Constructor_Revert_ZeroFactoryV3() public {
        IMangoStructs.cParamsRouter memory params = IMangoStructs.cParamsRouter({
            factoryV2: factoryV2,
            factoryV3: address(0),
            routerV2: routerV2,
            swapRouter02: swapRouter02,
            weth: address(mockWETH),
            taxFee: 300,
            referralFee: 100
        });
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        new MangoRouter002(params);
    }

    function test_Constructor_Revert_ZeroWETH() public {
        IMangoStructs.cParamsRouter memory params = IMangoStructs.cParamsRouter({
            factoryV2: factoryV2,
            factoryV3: factoryV3,
            routerV2: routerV2,
            swapRouter02: swapRouter02,
            weth: address(0),
            taxFee: 300,
            referralFee: 100
        });
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        new MangoRouter002(params);
    }

    // ============ ChangeTaxMan Tests ============

    function test_ChangeTaxMan_Success() public {
        address newTaxMan = address(0x8);
        vm.startPrank(owner);
        router.changeTaxMan(newTaxMan);
        vm.stopPrank();

        assertEq(router.taxMan(), newTaxMan);
    }

    function test_ChangeTaxMan_Revert_NotOwner() public {
        address newTaxMan = address(0x8);
        vm.expectRevert(IMangoErrors.NotOwner.selector);
        router.changeTaxMan(newTaxMan);
    }

    function test_ChangeTaxMan_Revert_ZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        router.changeTaxMan(address(0));
        vm.stopPrank();
    }

    // ============ SetReferralContract Tests ============

    function test_SetReferralContract_Success() public {
        vm.startPrank(owner);
        router.setReferralContract(address(referral));
        vm.stopPrank();

        assertEq(address(router.mangoReferral()), address(referral));
    }

    function test_SetReferralContract_Revert_NotOwner() public {
        vm.expectRevert(IMangoErrors.NotOwner.selector);
        router.setReferralContract(address(referral));
    }

    function test_SetReferralContract_Revert_ZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        router.setReferralContract(address(0));
        vm.stopPrank();
    }

    // ============ Fallback Tests ============

    function test_Fallback_Revert_DirectETHDepositsNotAllowed() public {
        vm.expectRevert(IMangoErrors.DirectETHDepositsNotAllowed.selector);
        (bool success, ) = address(router).call{value: 1 ether}("");
        require(!success, "Should have reverted");
    }

    // ============ Gas Benchmarks ============

    function test_Gas_ChangeTaxMan() public {
        address newTaxMan = address(0x8);
        vm.startPrank(owner);
        uint256 gasBefore = gasleft();
        router.changeTaxMan(newTaxMan);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for changeTaxMan:", gasUsed);
        vm.stopPrank();
    }

    function test_Gas_SetReferralContract() public {
        vm.startPrank(owner);
        uint256 gasBefore = gasleft();
        router.setReferralContract(address(referral));
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for setReferralContract:", gasUsed);
        vm.stopPrank();
    }
}

