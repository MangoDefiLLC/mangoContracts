// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MangoReferral} from "../contracts/mangoReferral.sol";
import {MANGO_DEFI_TOKEN} from "../contracts/mangoToken.sol";
import {IMangoStructs} from "../contracts/interfaces/IMangoStructs.sol";
import {IMangoErrors} from "../contracts/interfaces/IMangoErrors.sol";
import {IMangoRouter} from "../contracts/interfaces/IMangoRouter.sol";
import {IRouterV2} from "../contracts/interfaces/IRouterV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockRouter} from "./mocks/MockRouter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract MangoReferralTest is Test {
    MangoReferral public referral;
    MANGO_DEFI_TOKEN public mangoToken;
    MockRouter public mockRouter;
    MockERC20 public mockWETH;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);
    address public referrer1 = address(0x5);
    address public referrer2 = address(0x6);
    address public routerV2 = address(0x7);
    address public weth = address(0x8);

    event DistributedAmount(uint256 indexed totalAmount);
    event ReferralAdded(address indexed referrer, address indexed believer);

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy mock contracts
        mockWETH = new MockERC20("WETH", "WETH", 18);
        mockRouter = new MockRouter(address(0));
        
        // Deploy mango token
        IMangoStructs.cTokenParams memory tokenParams = IMangoStructs.cTokenParams({
            manager: address(0),
            uniswapRouterV2: routerV2,
            uniswapRouterV3: address(0),
            uniswapV3Factory: address(0)
        });
        mangoToken = new MANGO_DEFI_TOKEN(tokenParams);
        
        // Deploy referral contract
        IMangoStructs.cReferralParams memory params = IMangoStructs.cReferralParams({
            mangoRouter: IMangoRouter(address(mockRouter)),
            mangoToken: address(mangoToken),
            routerV2: IRouterV2(routerV2),
            weth: address(mockWETH)
        });
        referral = new MangoReferral(params);
        
        vm.stopPrank();
    }

    // ============ Constructor Tests ============

    function test_Constructor_Success() public {
        assertEq(referral.owner(), owner);
        assertEq(address(referral.mangoToken()), address(mangoToken));
        assertEq(address(referral.weth()), address(mockWETH));
    }

    function test_Constructor_Revert_ZeroRouter() public {
        IMangoStructs.cReferralParams memory params = IMangoStructs.cReferralParams({
            mangoRouter: IMangoRouter(address(0)),
            mangoToken: address(mangoToken),
            routerV2: IRouterV2(routerV2),
            weth: address(mockWETH)
        });
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        new MangoReferral(params);
    }

    function test_Constructor_Revert_ZeroToken() public {
        IMangoStructs.cReferralParams memory params = IMangoStructs.cReferralParams({
            mangoRouter: IMangoRouter(address(mockRouter)),
            mangoToken: address(0),
            routerV2: IRouterV2(routerV2),
            weth: address(mockWETH)
        });
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        new MangoReferral(params);
    }

    // ============ AddReferralChain Tests ============

    function test_AddReferralChain_Success() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit ReferralAdded(referrer1, user1);
        bool result = referral.addReferralChain(user1, referrer1);
        vm.stopPrank();

        assertTrue(result);
        assertEq(referral.getReferralChain(user1), referrer1);
    }

    function test_AddReferralChain_Revert_NotOwner() public {
        vm.expectRevert(IMangoErrors.NotOwner.selector);
        referral.addReferralChain(user1, referrer1);
    }

    function test_AddReferralChain_Revert_ZeroSwapper() public {
        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        referral.addReferralChain(address(0), referrer1);
        vm.stopPrank();
    }

    function test_AddReferralChain_Revert_ZeroReferrer() public {
        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        referral.addReferralChain(user1, address(0));
        vm.stopPrank();
    }

    function test_AddReferralChain_Revert_CannotReferYourself() public {
        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.CannotReferYourself.selector);
        referral.addReferralChain(user1, user1);
        vm.stopPrank();
    }

    function test_AddReferralChain_Revert_AlreadyExists() public {
        vm.startPrank(owner);
        referral.addReferralChain(user1, referrer1);
        vm.expectRevert(IMangoErrors.ReferralChainAlreadyExists.selector);
        referral.addReferralChain(user1, referrer2);
        vm.stopPrank();
    }

    // ============ DepositTokens Tests ============

    function test_DepositTokens_Success() public {
        vm.startPrank(owner);
        mangoToken.transfer(address(this), 1000e18);
        mangoToken.approve(address(referral), 1000e18);
        referral.depositTokens(address(mangoToken), 500e18);
        vm.stopPrank();

        assertEq(mangoToken.balanceOf(address(referral)), 500e18);
    }

    function test_DepositTokens_Revert_NotOwner() public {
        vm.startPrank(owner);
        mangoToken.transfer(user1, 1000e18);
        vm.stopPrank();

        vm.startPrank(user1);
        mangoToken.approve(address(referral), 1000e18);
        vm.expectRevert();
        referral.depositTokens(address(mangoToken), 500e18);
        vm.stopPrank();
    }

    // ============ AddToken Tests ============

    function test_AddToken_Success() public {
        MockERC20 newToken = new MockERC20("NewToken", "NEW", 18);
        vm.startPrank(owner);
        referral.addToken(address(newToken));
        vm.stopPrank();

        assertEq(address(referral.mangoToken()), address(newToken));
    }

    function test_AddToken_Revert_NotOwner() public {
        MockERC20 newToken = new MockERC20("NewToken", "NEW", 18);
        vm.expectRevert(IMangoErrors.NotOwner.selector);
        referral.addToken(address(newToken));
    }

    function test_AddToken_Revert_ZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        referral.addToken(address(0));
        vm.stopPrank();
    }

    // ============ AddRouter Tests ============

    function test_AddRouter_Success() public {
        address newRouter = address(0x9);
        vm.startPrank(owner);
        referral.addRouter(newRouter);
        vm.stopPrank();

        assertTrue(referral.whiteListed(newRouter));
    }

    function test_AddRouter_Revert_NotOwner() public {
        address newRouter = address(0x9);
        vm.expectRevert(IMangoErrors.NotOwner.selector);
        referral.addRouter(newRouter);
    }

    function test_AddRouter_Revert_ZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        referral.addRouter(address(0));
        vm.stopPrank();
    }

    // ============ BatchAddRouters Tests ============

    function test_BatchAddRouters_Success() public {
        address[] memory routers = new address[](3);
        routers[0] = address(0xA);
        routers[1] = address(0xB);
        routers[2] = address(0xC);

        vm.startPrank(owner);
        referral.batchAddRouters(routers);
        vm.stopPrank();

        assertTrue(referral.whiteListed(routers[0]));
        assertTrue(referral.whiteListed(routers[1]));
        assertTrue(referral.whiteListed(routers[2]));
    }

    function test_BatchAddRouters_Revert_NotOwner() public {
        address[] memory routers = new address[](1);
        routers[0] = address(0xA);

        vm.expectRevert(IMangoErrors.NotOwner.selector);
        referral.batchAddRouters(routers);
    }

    function test_BatchAddRouters_Revert_ZeroAddress() public {
        address[] memory routers = new address[](2);
        routers[0] = address(0xA);
        routers[1] = address(0);

        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        referral.batchAddRouters(routers);
        vm.stopPrank();
    }

    // ============ WithDrawTokens Tests ============

    function test_WithDrawTokens_Success() public {
        vm.startPrank(owner);
        mangoToken.transfer(address(referral), 1000e18);
        uint256 ownerBalanceBefore = mangoToken.balanceOf(owner);
        referral.withDrawTokens(address(mangoToken), 500e18);
        vm.stopPrank();

        assertEq(mangoToken.balanceOf(owner), ownerBalanceBefore + 500e18);
        assertEq(mangoToken.balanceOf(address(referral)), 500e18);
    }

    function test_WithDrawTokens_Revert_NotOwner() public {
        vm.startPrank(owner);
        mangoToken.transfer(address(referral), 1000e18);
        vm.stopPrank();

        vm.expectRevert(IMangoErrors.NotOwner.selector);
        referral.withDrawTokens(address(mangoToken), 500e18);
    }

    // ============ EthWithdraw Tests ============

    function test_EthWithdraw_Success() public {
        deal(address(referral), 1 ether);
        uint256 ownerBalanceBefore = owner.balance;

        vm.startPrank(owner);
        referral.ethWithdraw(0.5 ether);
        vm.stopPrank();

        assertEq(owner.balance, ownerBalanceBefore + 0.5 ether);
        assertEq(address(referral).balance, 0.5 ether);
    }

    function test_EthWithdraw_Revert_NotOwner() public {
        deal(address(referral), 1 ether);

        vm.expectRevert(IMangoErrors.NotOwner.selector);
        referral.ethWithdraw(0.5 ether);
    }

    // ============ Receive Tests ============

    function test_Receive_Revert_ETHNotAccepted() public {
        vm.expectRevert(IMangoErrors.ETHNotAccepted.selector);
        (bool success, ) = address(referral).call{value: 1 ether}("");
        require(!success, "Should have reverted");
    }

    // ============ GetReferralChain Tests ============

    function test_GetReferralChain_ReturnsZero() public {
        assertEq(referral.getReferralChain(user1), address(0));
    }

    function test_GetReferralChain_ReturnsReferrer() public {
        vm.startPrank(owner);
        referral.addReferralChain(user1, referrer1);
        vm.stopPrank();

        assertEq(referral.getReferralChain(user1), referrer1);
    }

    // ============ Gas Benchmarks ============

    function test_Gas_AddReferralChain() public {
        vm.startPrank(owner);
        uint256 gasBefore = gasleft();
        referral.addReferralChain(user1, referrer1);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for addReferralChain:", gasUsed);
        vm.stopPrank();
    }

    function test_Gas_BatchAddRouters() public {
        address[] memory routers = new address[](10);
        for (uint i = 0; i < 10; i++) {
            routers[i] = address(uint160(0x100 + i));
        }

        vm.startPrank(owner);
        uint256 gasBefore = gasleft();
        referral.batchAddRouters(routers);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for batchAddRouters(10):", gasUsed);
        vm.stopPrank();
    }

    // ============ Fuzz Tests ============

    function testFuzz_AddReferralChain(uint160 swapper, uint160 referrer) public {
        address swapperAddr = address(swapper);
        address referrerAddr = address(referrer);
        
        // Bound to avoid zero addresses and self-referral
        vm.assume(swapperAddr != address(0));
        vm.assume(referrerAddr != address(0));
        vm.assume(swapperAddr != referrerAddr);
        
        vm.startPrank(owner);
        bool result = referral.addReferralChain(swapperAddr, referrerAddr);
        vm.stopPrank();

        assertTrue(result);
        assertEq(referral.getReferralChain(swapperAddr), referrerAddr);
    }
}

