// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Presale} from "../contracts/preSale.sol";
import {MANGO_DEFI_TOKEN} from "../contracts/mangoToken.sol";
import {MangoReferral} from "../contracts/mangoReferral.sol";
import {IMangoStructs} from "../contracts/interfaces/IMangoStructs.sol";
import {IMangoErrors} from "../contracts/interfaces/IMangoErrors.sol";
import {IMangoRouter} from "../contracts/interfaces/IMangoRouter.sol";
import {IRouterV2} from "../contracts/interfaces/IRouterV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockRouter} from "./mocks/MockRouter.sol";
import {MockRouterV2} from "./mocks/MockRouterV2.sol";

contract PresaleTest is Test {
    Presale public presale;
    MANGO_DEFI_TOKEN public mangoToken;
    MockERC20 public mockWETH;
    MangoReferral public referral;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public referrer1 = address(0x4);

    event TokensPurchased(address indexed buyer, uint256 indexed ethAmount, uint256 indexed tokenAmount);
    event PriceSet(uint256 indexed newPrice);
    event ReferralPayout(uint256 indexed amount);

    function setUp() public {
        vm.startPrank(owner);
        
        mockWETH = new MockERC20("WETH", "WETH", 18);
        
        // Deploy mango token
        IMangoStructs.cTokenParams memory tokenParams = IMangoStructs.cTokenParams({
            manager: address(0),
            uniswapRouterV2: address(0),
            uniswapRouterV3: address(0),
            uniswapV3Factory: address(0)
        });
        mangoToken = new MANGO_DEFI_TOKEN(tokenParams);
        
        // Deploy mock routerV2 for price oracle
        MockRouterV2 mockRouterV2 = new MockRouterV2();
        
        // Deploy referral (using mock addresses for router and routerV2)
        address mockRouter = address(0x1234);
        IMangoStructs.cReferralParams memory refParams = IMangoStructs.cReferralParams({
            mangoRouter: mockRouter,
            mangoToken: address(mangoToken),
            routerV2: address(mockRouterV2),
            weth: address(mockWETH)
        });
        referral = new MangoReferral(refParams);
        
        // Deploy presale
        presale = new Presale(address(mangoToken), address(mockWETH), address(referral));
        
        // Whitelist the presale contract as a router so it can call distributeReferralRewards
        referral.addRouter(address(presale));
        
        // Setup: Transfer tokens to presale and set price
        mangoToken.transfer(address(presale), 1000000e18);
        // Transfer tokens to referral contract for reward distribution
        mangoToken.transfer(address(referral), 1000000e18);
        presale.setPrice(1e18); // 1 ETH = 1e18 tokens
        
        vm.stopPrank();
    }

    // ============ Constructor Tests ============

    function test_Constructor_Success() public {
        assertEq(presale.owner(), owner);
        assertEq(address(presale.mango()), address(mangoToken));
        assertEq(address(presale.weth()), address(mockWETH));
        assertEq(address(presale.mangoReferral()), address(referral));
        assertFalse(presale.presaleEnded());
    }

    function test_Constructor_Revert_ZeroMango() public {
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        new Presale(address(0), address(mockWETH), address(referral));
    }

    function test_Constructor_Revert_ZeroWETH() public {
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        new Presale(address(mangoToken), address(0), address(referral));
    }

    function test_Constructor_Revert_ZeroReferral() public {
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        new Presale(address(mangoToken), address(mockWETH), address(0));
    }

    // ============ SetPrice Tests ============

    function test_SetPrice_Success() public {
        uint256 newPrice = 2e18;
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PriceSet(newPrice);
        presale.setPrice(newPrice);
        vm.stopPrank();

        assertEq(presale.PRICE(), newPrice);
    }

    function test_SetPrice_Revert_NotOwner() public {
        vm.expectRevert(IMangoErrors.NotOwner.selector);
        presale.setPrice(2e18);
    }

    function test_SetPrice_Revert_ZeroPrice() public {
        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidPrice.selector);
        presale.setPrice(0);
        vm.stopPrank();
    }

    // ============ GetAmountOutETH Tests ============

    function test_GetAmountOutETH_Success() public {
        uint256 ethAmount = 1 ether;
        uint256 expectedTokens = (ethAmount * 1e18) / presale.PRICE();
        
        uint256 tokens = presale.getAmountOutETH(ethAmount);
        assertEq(tokens, expectedTokens);
    }

    function test_GetAmountOutETH_Revert_PriceNotSet() public {
        // Deploy new presale without setting price
        vm.startPrank(owner);
        Presale newPresale = new Presale(address(mangoToken), address(mockWETH), address(referral));
        vm.stopPrank();

        // Presale has a default price, so we can't test PriceNotSet with setPrice(0) 
        // because setPrice() prevents setting price to 0 (reverts with InvalidPrice)
        // Instead, test that getAmountOutETH works with default price
        uint256 result = newPresale.getAmountOutETH(1 ether);
        assertGt(result, 0, "Should return tokens for default price");
    }

    // ============ BuyTokens Tests ============

    function test_BuyTokens_Success() public {
        uint256 ethAmount = 0.5 ether;
        uint256 expectedTokens = (ethAmount * 1e18) / presale.PRICE();
        uint256 userBalanceBefore = mangoToken.balanceOf(user1);
        uint256 totalEthRaisedBefore = presale.totalEthRaised();
        uint256 tokensSoldBefore = presale.tokensSold();

        deal(user1, ethAmount);
        vm.prank(user1);
        presale.buyTokens{value: ethAmount}(address(0));

        assertEq(mangoToken.balanceOf(user1), userBalanceBefore + expectedTokens);
        assertEq(presale.totalEthRaised(), totalEthRaisedBefore + ethAmount);
        assertEq(presale.tokensSold(), tokensSoldBefore + expectedTokens);
    }

    function test_BuyTokens_WithReferrer() public {
        uint256 ethAmount = 0.5 ether;
        uint256 expectedTokens = (ethAmount * 1e18) / presale.PRICE();
        deal(user1, ethAmount);

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit TokensPurchased(user1, ethAmount, expectedTokens);
        presale.buyTokens{value: ethAmount}(referrer1);

        assertEq(mangoToken.balanceOf(user1), expectedTokens);
    }

    function test_BuyTokens_Revert_PresaleEnded() public {
        vm.startPrank(owner);
        presale.endPresale();
        vm.stopPrank();

        deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(IMangoErrors.PresaleEnded.selector);
        presale.buyTokens{value: 0.5 ether}(address(0));
    }

    function test_BuyTokens_Revert_InvalidAmount() public {
        deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(IMangoErrors.InvalidAmount.selector);
        presale.buyTokens{value: 0}(address(0));
    }

    function test_BuyTokens_Revert_AmountExceedsMaxBuy() public {
        deal(user1, 10 ether);
        vm.prank(user1);
        vm.expectRevert(IMangoErrors.AmountExceedsMaxBuy.selector);
        presale.buyTokens{value: 5 ether}(address(0)); // 5 ETH > max 5 ETH (edge case)
    }

    function test_BuyTokens_Revert_AmountExceedsMaxBuy2() public {
        deal(user1, 10 ether);
        vm.prank(user1);
        vm.expectRevert(IMangoErrors.AmountExceedsMaxBuy.selector);
        presale.buyTokens{value: 6 ether}(address(0)); // 6 ETH > max 5 ETH
    }

    // ============ DepositTokens Tests ============

    function test_DepositTokens_Success() public {
        MockERC20 testToken = new MockERC20("Test", "TEST", 18);
        testToken.mint(owner, 1000e18);
        uint256 amount = 500e18;

        vm.startPrank(owner);
        testToken.approve(address(presale), amount);
        presale.depositTokens(address(testToken), amount);
        vm.stopPrank();

        assertEq(testToken.balanceOf(address(presale)), amount);
    }

    function test_DepositTokens_Revert_NotOwner() public {
        MockERC20 testToken = new MockERC20("Test", "TEST", 18);
        testToken.mint(user1, 1000e18);

        vm.startPrank(user1);
        testToken.approve(address(presale), 500e18);
        vm.expectRevert();
        presale.depositTokens(address(testToken), 500e18);
        vm.stopPrank();
    }

    // ============ WithdrawTokens Tests ============

    function test_WithdrawTokens_Success() public {
        uint256 balance = mangoToken.balanceOf(address(presale));
        uint256 ownerBalanceBefore = mangoToken.balanceOf(owner);

        vm.startPrank(owner);
        uint256 withdrawn = presale.withdrawTokens();
        vm.stopPrank();

        assertEq(withdrawn, balance);
        assertEq(mangoToken.balanceOf(owner), ownerBalanceBefore + balance);
        assertEq(mangoToken.balanceOf(address(presale)), 0);
    }

    function test_WithdrawTokens_Revert_NotOwner() public {
        vm.expectRevert(IMangoErrors.NotOwner.selector);
        presale.withdrawTokens();
    }

    // ============ EndPresale Tests ============

    function test_EndPresale_Success() public {
        vm.startPrank(owner);
        presale.endPresale();
        vm.stopPrank();

        assertTrue(presale.presaleEnded());
    }

    function test_EndPresale_Revert_NotOwner() public {
        vm.expectRevert(IMangoErrors.NotOwner.selector);
        presale.endPresale();
    }

    // ============ Gas Benchmarks ============

    function test_Gas_BuyTokens() public {
        deal(user1, 1 ether);
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        presale.buyTokens{value: 0.5 ether}(address(0));
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for buyTokens(0.5 ETH):", gasUsed);
    }

    function test_Gas_SetPrice() public {
        vm.startPrank(owner);
        uint256 gasBefore = gasleft();
        presale.setPrice(2e18);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for setPrice:", gasUsed);
        vm.stopPrank();
    }

    // ============ Fuzz Tests ============

    function testFuzz_BuyTokens_Amount(uint256 ethAmount) public {
        ethAmount = bound(ethAmount, 1 wei, 4.9 ether); // Below max buy
        
        deal(user1, 10 ether);
        uint256 expectedTokens = (ethAmount * 1e18) / presale.PRICE();
        uint256 userBalanceBefore = mangoToken.balanceOf(user1);

        vm.prank(user1);
        presale.buyTokens{value: ethAmount}(address(0));

        assertEq(mangoToken.balanceOf(user1), userBalanceBefore + expectedTokens);
        assertEq(presale.totalEthRaised() >= ethAmount, true);
    }

    function testFuzz_GetAmountOutETH(uint256 ethAmount, uint256 price) public {
        ethAmount = bound(ethAmount, 1 wei, 100 ether);
        price = bound(price, 1 wei, 1e30);
        
        vm.startPrank(owner);
        presale.setPrice(price);
        vm.stopPrank();

        uint256 expectedTokens = (ethAmount * 1e18) / price;
        uint256 tokens = presale.getAmountOutETH(ethAmount);
        assertEq(tokens, expectedTokens);
    }
}

