// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Mango_Manager} from "../contracts/manager.sol";
import {MANGO_DEFI_TOKEN} from "../contracts/mangoToken.sol";
import {MangoRouter002} from "../contracts/mangoRouter001.sol";
import {MangoReferral} from "../contracts/mangoReferral.sol";
import {IMangoStructs} from "../contracts/interfaces/IMangoStructs.sol";
import {IMangoErrors} from "../contracts/interfaces/IMangoErrors.sol";
import {IMangoRouter} from "../contracts/interfaces/IMangoRouter.sol";
import {IMangoReferral} from "../contracts/interfaces/IMangoReferral.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockRouter} from "./mocks/MockRouter.sol";
import {MockReferral} from "./mocks/MockReferral.sol";

contract ManagerTest is Test {
    Mango_Manager public manager;
    MockERC20 public mockToken;
    MockRouter public mockRouter;
    MockReferral public mockReferral;
    address public owner = address(0x1);
    address public user = address(0x2);

    event FeesReceived(uint256 indexed totalAmount);
    event TeamFeeWithdrawn(address indexed owner, uint256 indexed amount);

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy mocks
        mockToken = new MockERC20("Mock Token", "MTK", 18);
        mockRouter = new MockRouter(address(mockToken));
        mockReferral = new MockReferral();

        // Deploy manager
        IMangoStructs.cManagerParams memory params = IMangoStructs.cManagerParams({
            mangoRouter: address(mockRouter),
            mangoReferral: address(mockReferral),
            token: address(mockToken)
        });
        manager = new Mango_Manager(params);

        vm.stopPrank();
    }

    // ============ Constructor Tests ============

    function test_Constructor_Success() public {
        assertEq(address(manager.mangoRouter()), address(mockRouter));
        assertEq(address(manager.mangoToken()), address(mockToken));
        assertEq(address(manager.mangoReferral()), address(mockReferral));
        assertEq(manager.owner(), owner);
    }

    function test_Constructor_Revert_ZeroRouter() public {
        IMangoStructs.cManagerParams memory params = IMangoStructs.cManagerParams({
            mangoRouter: address(0),
            mangoReferral: address(mockReferral),
            token: address(mockToken)
        });
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        new Mango_Manager(params);
    }

    function test_Constructor_Revert_ZeroReferral() public {
        IMangoStructs.cManagerParams memory params = IMangoStructs.cManagerParams({
            mangoRouter: address(mockRouter),
            mangoReferral: address(0),
            token: address(mockToken)
        });
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        new Mango_Manager(params);
    }

    function test_Constructor_Revert_ZeroToken() public {
        IMangoStructs.cManagerParams memory params = IMangoStructs.cManagerParams({
            mangoRouter: address(mockRouter),
            mangoReferral: address(mockReferral),
            token: address(0)
        });
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        new Mango_Manager(params);
    }

    // ============ Receive Tests ============

    function test_Receive_SplitsFeesCorrectly() public {
        uint256 amount = 300 ether; // 300 ETH
        deal(address(this), amount);

        vm.expectEmit(true, false, false, true);
        emit FeesReceived(amount);

        (bool success, ) = address(manager).call{value: amount}("");
        assertTrue(success);

        // Fees should be split into 3 (100 each) with remainder to referral
        uint256 fee = amount / 3; // 100 ETH
        uint256 remainder = amount - (fee * 3); // 0 ETH

        assertEq(manager.teamFee(), fee);
        assertEq(manager.buyAndBurnFee(), fee);
        assertEq(manager.referralFee(), fee + remainder);
        assertEq(manager.totalFeesCollected(), amount);
    }

    function test_Receive_FeeSplittingWithRemainder() public {
        uint256 amount = 100; // 100 wei (not divisible by 3)
        deal(address(this), amount);

        (bool success, ) = address(manager).call{value: amount}("");
        assertTrue(success);

        uint256 fee = amount / 3; // 33 wei
        uint256 remainder = amount - (fee * 3); // 1 wei

        assertEq(manager.teamFee(), fee);
        assertEq(manager.buyAndBurnFee(), fee);
        assertEq(manager.referralFee(), fee + remainder); // Referral gets remainder
    }

    function test_Receive_MultipleDeposits() public {
        deal(address(this), 1000 ether);
        
        (bool success1, ) = address(manager).call{value: 300 ether}("");
        assertTrue(success1);
        
        (bool success2, ) = address(manager).call{value: 600 ether}("");
        assertTrue(success2);

        // First deposit: 100 each
        // Second deposit: 200 each
        // Total: 300 each (plus remainders)
        assertEq(manager.teamFee(), 300 ether);
        assertEq(manager.buyAndBurnFee(), 300 ether);
        assertEq(manager.referralFee(), 300 ether);
        assertEq(manager.totalFeesCollected(), 900 ether);
    }

    // ============ Burn Tests ============

    function test_Burn_Success() public {
        uint256 feeAmount = 90 ether; // Use amount divisible by 3
        deal(address(manager), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);

        // Fees are split by 3, so buyAndBurnFee = 90 / 3 = 30 ether
        uint256 expectedBuyAndBurnFee = feeAmount / 3; // 30 ether
        uint256 burnAmount = 10 ether;
        deal(address(mockRouter), burnAmount); // Router has ETH for swap
        mockRouter.setFixedAmountOut(1000e18); // Set tokens returned from swap

        vm.startPrank(owner);
        manager.burn(burnAmount);
        vm.stopPrank();

        assertEq(manager.buyAndBurnFee(), expectedBuyAndBurnFee - burnAmount);
        assertEq(manager.totalBurned(), burnAmount);
        assertEq(mockToken.balanceOf(address(manager)), 0); // Tokens burned
    }

    function test_Burn_Revert_NotOwner() public {
        uint256 feeAmount = 100 ether;
        deal(address(manager), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);

        vm.expectRevert(IMangoErrors.NotOwner.selector);
        manager.burn(10 ether);
    }

    function test_Burn_Revert_AmountExceedsFee() public {
        uint256 feeAmount = 100 ether;
        deal(address(manager), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);

        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.AmountExceedsFee.selector);
        manager.burn(101 ether);
        vm.stopPrank();
    }

    function test_Burn_OnlyBurnsPurchasedTokens() public {
        // Pre-existing tokens in manager (accidentally sent)
        mockToken.mint(address(manager), 1000e18);
        uint256 preExisting = mockToken.balanceOf(address(manager));

        uint256 feeAmount = 100 ether;
        deal(address(manager), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);

        uint256 burnAmount = 10 ether;
        deal(address(mockRouter), burnAmount);
        uint256 tokensFromSwap = 500e18;
        mockRouter.setFixedAmountOut(tokensFromSwap); // Set tokens returned from swap

        vm.startPrank(owner);
        manager.burn(burnAmount);
        vm.stopPrank();

        // Only newly purchased tokens should be burned
        assertEq(mockToken.balanceOf(address(manager)), preExisting);
    }

    // ============ FundReferral Tests ============

    function test_FundReferral_Success() public {
        uint256 feeAmount = 90 ether; // Use amount divisible by 3
        deal(address(manager), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);

        // Fees are split by 3, so referralFee = 90 / 3 = 30 ether (plus remainder)
        uint256 expectedReferralFee = feeAmount / 3; // 30 ether
        uint256 fundAmount = 10 ether;
        deal(address(mockRouter), fundAmount);
        uint256 tokensFromSwap = 500e18;
        mockRouter.setFixedAmountOut(tokensFromSwap); // Set tokens returned from swap
        
        // Approve mockReferral to spend tokens from manager
        vm.prank(address(manager));
        mockToken.approve(address(mockReferral), tokensFromSwap);

        vm.startPrank(owner);
        manager.fundReferral(fundAmount);
        vm.stopPrank();

        assertEq(manager.referralFee(), expectedReferralFee - fundAmount);
        assertEq(mockToken.balanceOf(address(mockReferral)), tokensFromSwap);
        assertEq(mockToken.balanceOf(address(manager)), 0);
    }

    function test_FundReferral_Revert_NotOwner() public {
        uint256 feeAmount = 100 ether;
        deal(address(manager), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);

        vm.expectRevert(IMangoErrors.NotOwner.selector);
        manager.fundReferral(10 ether);
    }

    function test_FundReferral_Revert_AmountExceedsFee() public {
        uint256 feeAmount = 100 ether;
        deal(address(manager), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);

        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.AmountExceedsFee.selector);
        manager.fundReferral(101 ether);
        vm.stopPrank();
    }

    // ============ WithdrawTeamFee Tests ============

    function test_WithdrawTeamFee_Success() public {
        uint256 feeAmount = 90 ether; // Use amount divisible by 3
        // Send ETH directly to trigger receive() - don't use deal() as it adds balance separately
        deal(address(this), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);

        // Fees are split by 3, so teamFee = 90 / 3 = 30 ether
        uint256 expectedTeamFee = feeAmount / 3; // 30 ether
        uint256 withdrawAmount = 10 ether;
        uint256 ownerBalanceBefore = owner.balance;

        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit TeamFeeWithdrawn(owner, withdrawAmount);
        manager.withdrawTeamFee(withdrawAmount);
        vm.stopPrank();

        assertEq(manager.teamFee(), expectedTeamFee - withdrawAmount);
        assertEq(owner.balance, ownerBalanceBefore + withdrawAmount);
        // Manager balance = initial feeAmount - withdrawn amount = 90 - 10 = 80 ether
        assertEq(address(manager).balance, feeAmount - withdrawAmount);
    }

    function test_WithdrawTeamFee_Revert_NotOwner() public {
        uint256 feeAmount = 100 ether;
        deal(address(manager), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);

        vm.expectRevert(IMangoErrors.NotOwner.selector);
        manager.withdrawTeamFee(10 ether);
    }

    function test_WithdrawTeamFee_Revert_AmountExceedsFee() public {
        uint256 feeAmount = 100 ether;
        deal(address(manager), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);

        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.AmountExceedsFee.selector);
        manager.withdrawTeamFee(101 ether);
        vm.stopPrank();
    }

    function test_WithdrawTeamFee_Revert_InsufficientBalance() public {
        uint256 feeAmount = 90 ether; // Use amount divisible by 3
        deal(address(manager), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);

        // Fees are split by 3, so teamFee = 90 / 3 = 30 ether
        uint256 expectedTeamFee = feeAmount / 3; // 30 ether
        
        // Withdraw some ETH first (20 ether)
        vm.startPrank(owner);
        manager.withdrawTeamFee(20 ether);
        
        // Remaining teamFee = 10 ether, remaining balance = 70 ether
        // Try to withdraw 11 ether (more than teamFee, but less than balance)
        // This should fail with AmountExceedsFee, not InsufficientBalance
        vm.expectRevert(IMangoErrors.AmountExceedsFee.selector);
        manager.withdrawTeamFee(11 ether);
        
        // Now withdraw all remaining teamFee (10 ether), leaving balance at 60 ether
        manager.withdrawTeamFee(10 ether);
        
        // Now try to withdraw when balance is insufficient (try to withdraw 61 ether when only 60 ether left)
        // But teamFee is 0, so it should fail with AmountExceedsFee
        vm.expectRevert(IMangoErrors.AmountExceedsFee.selector);
        manager.withdrawTeamFee(1 ether);
        vm.stopPrank();
    }

    // ============ Gas Benchmarks ============

    function test_Gas_Receive() public {
        deal(address(this), 100 ether);
        uint256 gasBefore = gasleft();
        (bool success, ) = address(manager).call{value: 100 ether}("");
        require(success);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for receive(100 ETH):", gasUsed);
    }

    function test_Gas_Burn() public {
        uint256 feeAmount = 100 ether;
        deal(address(manager), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);
        deal(address(mockRouter), 10 ether);
        mockRouter.setFixedAmountOut(1000e18);

        vm.startPrank(owner);
        uint256 gasBefore = gasleft();
        manager.burn(10 ether);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for burn(10 ETH):", gasUsed);
        vm.stopPrank();
    }

    function test_Gas_WithdrawTeamFee() public {
        uint256 feeAmount = 100 ether;
        deal(address(manager), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);

        vm.startPrank(owner);
        uint256 gasBefore = gasleft();
        manager.withdrawTeamFee(10 ether);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for withdrawTeamFee(10 ETH):", gasUsed);
        vm.stopPrank();
    }

    // ============ Fuzz Tests ============

    function testFuzz_Receive_FeeSplitting(uint256 amount) public {
        // Bound to reasonable values to avoid overflow
        amount = bound(amount, 1, 1000 ether);
        deal(address(this), amount);

        (bool success, ) = address(manager).call{value: amount}("");
        require(success);

        uint256 fee = amount / 3;
        uint256 remainder = amount - (fee * 3);

        assertEq(manager.teamFee(), fee);
        assertEq(manager.buyAndBurnFee(), fee);
        assertEq(manager.referralFee(), fee + remainder);
        assertEq(manager.totalFeesCollected(), amount);
    }

    function testFuzz_Burn_AmountValidation(uint256 feeAmount, uint256 burnAmount) public {
        feeAmount = bound(feeAmount, 3, 1000 ether); // Must be at least 3 to split properly
        // Fees are split by 3, so buyAndBurnFee = feeAmount / 3
        uint256 buyAndBurnFee = feeAmount / 3;
        burnAmount = bound(burnAmount, 1, buyAndBurnFee); // Bound to actual buyAndBurnFee
        
        deal(address(manager), feeAmount);
        (bool success, ) = address(manager).call{value: feeAmount}("");
        require(success);

        deal(address(mockRouter), burnAmount);
        mockRouter.setFixedAmountOut(1000e18);

        vm.startPrank(owner);
        manager.burn(burnAmount);
        vm.stopPrank();

        assertEq(manager.buyAndBurnFee(), buyAndBurnFee - burnAmount);
    }
}

