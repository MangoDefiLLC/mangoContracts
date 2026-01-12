// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MANGO_DEFI_TOKEN} from "../contracts/mangoToken.sol";
import {IMangoStructs} from "../contracts/interfaces/IMangoStructs.sol";
import {IMangoErrors} from "../contracts/interfaces/IMangoErrors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MangoTokenTest is Test {
    MANGO_DEFI_TOKEN public token;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public pair = address(0x4);
    address public v3Pool = address(0x5);
    address public taxWallet = address(0x6);
    address public newOwner = address(0x7);
    address public routerV2 = address(0x8);
    address public routerV3 = address(0x9);
    address public factoryV3 = address(0xA);

    event PairAdded(address indexed pair);
    event V3PoolAdded(address indexed pool);
    event TaxWalletUpdated(address indexed newTaxWallet);
    event NewOwner(address indexed newOwner);

    function setUp() public {
        vm.startPrank(owner);
        
        IMangoStructs.cTokenParams memory params = IMangoStructs.cTokenParams({
            manager: address(0),
            uniswapRouterV2: routerV2,
            uniswapRouterV3: routerV3,
            uniswapV3Factory: factoryV3
        });
        
        token = new MANGO_DEFI_TOKEN(params);
        vm.stopPrank();
    }

    // ============ Constructor Tests ============

    function test_Constructor_Success() public {
        assertEq(token.owner(), owner);
        assertEq(token.taxWallet(), owner);
        assertEq(token.uniswapRouterV2(), routerV2);
        assertEq(token.uniswapRouterV3(), routerV3);
        assertEq(token.uniswapV3Factory(), factoryV3);
        assertEq(token.totalSupply(), 100000000000e18);
        assertEq(token.balanceOf(owner), 100000000000e18);
    }

    function test_Constructor_ExcludesOwnerFromTax() public {
        assertTrue(token.isExcludedFromTax(owner));
    }

    function test_Constructor_ExcludesContractFromTax() public {
        assertTrue(token.isExcludedFromTax(address(token)));
    }

    function test_Constructor_ExcludesRouterV2FromTax() public {
        assertTrue(token.isExcludedFromTax(routerV2));
    }

    // ============ Constants Tests ============

    function test_BUY_TAX_Is200() public {
        assertEq(token.BUY_TAX(), 200); // 2%
    }

    function test_SELL_TAX_Is300() public {
        assertEq(token.SELL_TAX(), 300); // 3%
    }

    function test_BASIS_POINT_Is10000() public {
        assertEq(token.BASIS_POINT(), 10000);
    }

    function test_V3FeeTiers() public {
        uint24[5] memory expected = [uint24(100), uint24(200), uint24(10000), uint24(300), uint24(30000)];
        for (uint i = 0; i < 5; i++) {
            assertEq(token.v3FeeTiers(i), expected[i]);
        }
    }

    // ============ Transfer Tests (No Tax) ============

    function test_Transfer_NoTax_WhenBothExcluded() public {
        vm.startPrank(owner);
        token.excludeAddress(user1);
        token.excludeAddress(user2);
        // Transfer tokens to user1 first
        token.transfer(user1, 1000e18);
        vm.stopPrank();

        uint256 amount = 1000e18;
        uint256 balanceBefore = token.balanceOf(user2);
        
        vm.prank(user1);
        token.transfer(user2, amount);
        
        assertEq(token.balanceOf(user2), balanceBefore + amount);
    }

    function test_Transfer_NoTax_WhenSenderExcluded() public {
        vm.startPrank(owner);
        token.excludeAddress(user1);
        // Transfer tokens to user1 first
        token.transfer(user1, 1000e18);
        vm.stopPrank();

        uint256 amount = 1000e18;
        uint256 balanceBefore = token.balanceOf(user2);
        
        vm.prank(user1);
        token.transfer(user2, amount);
        
        assertEq(token.balanceOf(user2), balanceBefore + amount);
    }

    function test_Transfer_NoTax_WhenReceiverExcluded() public {
        vm.startPrank(owner);
        token.excludeAddress(user2);
        vm.stopPrank();

        vm.deal(user1, 1 ether);
        vm.startPrank(owner);
        token.transfer(user1, 1000e18);
        vm.stopPrank();

        uint256 amount = 1000e18;
        uint256 balanceBefore = token.balanceOf(user2);
        
        vm.prank(user1);
        token.transfer(user2, amount);
        
        assertEq(token.balanceOf(user2), balanceBefore + amount);
    }

    // ============ Buy Tax Tests ============

    function test_Transfer_BuyTax_WhenFromPair() public {
        vm.startPrank(owner);
        token.addPair(pair);
        token.setTaxWallet(taxWallet);
        vm.stopPrank();

        vm.startPrank(owner);
        token.transfer(pair, 10000e18);
        vm.stopPrank();

        uint256 amount = 1000e18;
        uint256 buyTax = (amount * 200) / 10000; // 2%
        uint256 amountAfterTax = amount - buyTax;

        uint256 user2BalanceBefore = token.balanceOf(user2);
        uint256 taxWalletBalanceBefore = token.balanceOf(taxWallet);

        vm.prank(pair);
        token.transfer(user2, amount);

        assertEq(token.balanceOf(user2), user2BalanceBefore + amountAfterTax);
        assertEq(token.balanceOf(taxWallet), taxWalletBalanceBefore + buyTax);
    }

    function test_Transfer_BuyTax_WhenFromV3Pool() public {
        vm.startPrank(owner);
        token.addV3Pool(v3Pool);
        token.setTaxWallet(taxWallet);
        vm.stopPrank();

        vm.startPrank(owner);
        token.transfer(v3Pool, 10000e18);
        vm.stopPrank();

        uint256 amount = 1000e18;
        uint256 buyTax = (amount * 200) / 10000; // 2%
        uint256 amountAfterTax = amount - buyTax;

        uint256 user2BalanceBefore = token.balanceOf(user2);
        uint256 taxWalletBalanceBefore = token.balanceOf(taxWallet);

        vm.prank(v3Pool);
        token.transfer(user2, amount);

        assertEq(token.balanceOf(user2), user2BalanceBefore + amountAfterTax);
        assertEq(token.balanceOf(taxWallet), taxWalletBalanceBefore + buyTax);
    }

    // ============ Sell Tax Tests ============

    function test_Transfer_SellTax_WhenToPair() public {
        vm.startPrank(owner);
        token.addPair(pair);
        token.setTaxWallet(taxWallet);
        token.transfer(user1, 10000e18);
        vm.stopPrank();

        uint256 amount = 1000e18;
        uint256 sellTax = (amount * 300) / 10000; // 3%
        uint256 amountAfterTax = amount - sellTax;

        uint256 pairBalanceBefore = token.balanceOf(pair);
        uint256 taxWalletBalanceBefore = token.balanceOf(taxWallet);

        vm.prank(user1);
        token.transfer(pair, amount);

        assertEq(token.balanceOf(pair), pairBalanceBefore + amountAfterTax);
        assertEq(token.balanceOf(taxWallet), taxWalletBalanceBefore + sellTax);
    }

    function test_Transfer_SellTax_WhenToV3Pool() public {
        vm.startPrank(owner);
        token.addV3Pool(v3Pool);
        token.setTaxWallet(taxWallet);
        token.transfer(user1, 10000e18);
        vm.stopPrank();

        uint256 amount = 1000e18;
        uint256 sellTax = (amount * 300) / 10000; // 3%
        uint256 amountAfterTax = amount - sellTax;

        uint256 poolBalanceBefore = token.balanceOf(v3Pool);
        uint256 taxWalletBalanceBefore = token.balanceOf(taxWallet);

        vm.prank(user1);
        token.transfer(v3Pool, amount);

        assertEq(token.balanceOf(v3Pool), poolBalanceBefore + amountAfterTax);
        assertEq(token.balanceOf(taxWallet), taxWalletBalanceBefore + sellTax);
    }

    // ============ AddPair Tests ============

    function test_AddPair_Success() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PairAdded(pair);
        token.addPair(pair);
        vm.stopPrank();

        assertTrue(token.isPair(pair));
    }

    function test_AddPair_Revert_NotOwner() public {
        vm.expectRevert();
        token.addPair(pair);
    }

    function test_AddPair_Revert_ZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        token.addPair(address(0));
        vm.stopPrank();
    }

    // ============ AddV3Pool Tests ============

    function test_AddV3Pool_Success() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit V3PoolAdded(v3Pool);
        token.addV3Pool(v3Pool);
        vm.stopPrank();

        assertTrue(token.isV3Pool(v3Pool));
    }

    function test_AddV3Pool_Revert_NotOwner() public {
        vm.expectRevert();
        token.addV3Pool(v3Pool);
    }

    function test_AddV3Pool_Revert_ZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        token.addV3Pool(address(0));
        vm.stopPrank();
    }

    // ============ ExcludeAddress Tests ============

    function test_ExcludeAddress_Success() public {
        vm.startPrank(owner);
        bool result = token.excludeAddress(user1);
        vm.stopPrank();

        assertTrue(result);
        assertTrue(token.isExcludedFromTax(user1));
    }

    function test_ExcludeAddress_Revert_NotOwner() public {
        vm.expectRevert();
        token.excludeAddress(user1);
    }

    // ============ BatchAddPairs Tests ============

    function test_BatchAddPairs_Success() public {
        address[] memory pairs = new address[](3);
        pairs[0] = address(0xA);
        pairs[1] = address(0xB);
        pairs[2] = address(0xC);

        vm.startPrank(owner);
        token.batchAddPairs(pairs);
        vm.stopPrank();

        assertTrue(token.isPair(pairs[0]));
        assertTrue(token.isPair(pairs[1]));
        assertTrue(token.isPair(pairs[2]));
    }

    function test_BatchAddPairs_Revert_NotOwner() public {
        address[] memory pairs = new address[](1);
        pairs[0] = pair;

        vm.expectRevert();
        token.batchAddPairs(pairs);
    }

    function test_BatchAddPairs_Revert_ZeroAddress() public {
        address[] memory pairs = new address[](2);
        pairs[0] = pair;
        pairs[1] = address(0);

        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        token.batchAddPairs(pairs);
        vm.stopPrank();
    }

    // ============ BatchAddV3Pools Tests ============

    function test_BatchAddV3Pools_Success() public {
        address[] memory pools = new address[](3);
        pools[0] = address(0xD);
        pools[1] = address(0xE);
        pools[2] = address(0xF);

        vm.startPrank(owner);
        token.batchAddV3Pools(pools);
        vm.stopPrank();

        assertTrue(token.isV3Pool(pools[0]));
        assertTrue(token.isV3Pool(pools[1]));
        assertTrue(token.isV3Pool(pools[2]));
    }

    function test_BatchAddV3Pools_Revert_NotOwner() public {
        address[] memory pools = new address[](1);
        pools[0] = v3Pool;

        vm.expectRevert();
        token.batchAddV3Pools(pools);
    }

    function test_BatchAddV3Pools_Revert_ZeroAddress() public {
        address[] memory pools = new address[](2);
        pools[0] = v3Pool;
        pools[1] = address(0);

        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        token.batchAddV3Pools(pools);
        vm.stopPrank();
    }

    // ============ BatchExcludeAddresses Tests ============

    function test_BatchExcludeAddresses_Success() public {
        address[] memory addresses = new address[](3);
        addresses[0] = user1;
        addresses[1] = user2;
        addresses[2] = address(0x10);

        vm.startPrank(owner);
        token.batchExcludeAddresses(addresses);
        vm.stopPrank();

        assertTrue(token.isExcludedFromTax(addresses[0]));
        assertTrue(token.isExcludedFromTax(addresses[1]));
        assertTrue(token.isExcludedFromTax(addresses[2]));
    }

    function test_BatchExcludeAddresses_Revert_NotOwner() public {
        address[] memory addresses = new address[](1);
        addresses[0] = user1;

        vm.expectRevert();
        token.batchExcludeAddresses(addresses);
    }

    function test_BatchExcludeAddresses_Revert_ZeroAddress() public {
        address[] memory addresses = new address[](2);
        addresses[0] = user1;
        addresses[1] = address(0);

        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        token.batchExcludeAddresses(addresses);
        vm.stopPrank();
    }

    // ============ SetTaxWallet Tests ============

    function test_SetTaxWallet_Success() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit TaxWalletUpdated(taxWallet);
        token.setTaxWallet(taxWallet);
        vm.stopPrank();

        assertEq(token.taxWallet(), taxWallet);
    }

    function test_SetTaxWallet_Revert_NotOwner() public {
        vm.expectRevert(IMangoErrors.NotOwner.selector);
        token.setTaxWallet(taxWallet);
    }

    function test_SetTaxWallet_Revert_ZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        token.setTaxWallet(address(0));
        vm.stopPrank();
    }

    // ============ ChangeOwner Tests ============

    function test_ChangeOwner_Success() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit NewOwner(newOwner);
        token.changeOwner(newOwner);
        vm.stopPrank();

        assertEq(token.owner(), newOwner);
    }

    function test_ChangeOwner_Revert_NotOwner() public {
        vm.expectRevert(IMangoErrors.NotOwner.selector);
        token.changeOwner(newOwner);
    }

    function test_ChangeOwner_Revert_ZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IMangoErrors.InvalidAddress.selector);
        token.changeOwner(address(0));
        vm.stopPrank();
    }

    // ============ IsV3PoolAddress Tests ============

    function test_IsV3PoolAddress_ReturnsFalse() public {
        assertFalse(token.isV3PoolAddress(v3Pool));
    }

    function test_IsV3PoolAddress_ReturnsTrue() public {
        vm.startPrank(owner);
        token.addV3Pool(v3Pool);
        vm.stopPrank();

        assertTrue(token.isV3PoolAddress(v3Pool));
    }

    // ============ Legacy Getters Tests ============

    function test_IsExcludedFromTax_Getter() public {
        assertTrue(token.isExcludedFromTax(owner));
        assertFalse(token.isExcludedFromTax(user1));
    }

    function test_IsPair_Getter() public {
        assertFalse(token.isPair(pair));
        
        vm.startPrank(owner);
        token.addPair(pair);
        vm.stopPrank();
        
        assertTrue(token.isPair(pair));
    }

    function test_IsV3Pool_Getter() public {
        assertFalse(token.isV3Pool(v3Pool));
        
        vm.startPrank(owner);
        token.addV3Pool(v3Pool);
        vm.stopPrank();
        
        assertTrue(token.isV3Pool(v3Pool));
    }

    // ============ Gas Benchmarks ============

    function test_Gas_Transfer_NoTax() public {
        vm.startPrank(owner);
        token.excludeAddress(user1);
        token.excludeAddress(user2);
        token.transfer(user1, 1000e18);
        vm.stopPrank();

        vm.prank(user1);
        uint256 gasBefore = gasleft();
        token.transfer(user2, 100e18);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for transfer (no tax):", gasUsed);
    }

    function test_Gas_Transfer_WithBuyTax() public {
        vm.startPrank(owner);
        token.addPair(pair);
        token.setTaxWallet(taxWallet);
        token.transfer(pair, 1000e18);
        vm.stopPrank();

        vm.prank(pair);
        uint256 gasBefore = gasleft();
        token.transfer(user2, 100e18);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for transfer (buy tax):", gasUsed);
    }

    function test_Gas_Transfer_WithSellTax() public {
        vm.startPrank(owner);
        token.addPair(pair);
        token.setTaxWallet(taxWallet);
        token.transfer(user1, 1000e18);
        vm.stopPrank();

        vm.prank(user1);
        uint256 gasBefore = gasleft();
        token.transfer(pair, 100e18);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for transfer (sell tax):", gasUsed);
    }

    function test_Gas_BatchAddPairs() public {
        address[] memory pairs = new address[](10);
        for (uint i = 0; i < 10; i++) {
            pairs[i] = address(uint160(0x100 + i));
        }

        vm.startPrank(owner);
        uint256 gasBefore = gasleft();
        token.batchAddPairs(pairs);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for batchAddPairs(10):", gasUsed);
        vm.stopPrank();
    }

    // ============ Fuzz Tests ============

    function testFuzz_Transfer_NoTax_Amount(uint256 amount) public {
        amount = bound(amount, 1, 1000000e18);
        
        vm.startPrank(owner);
        token.excludeAddress(user1);
        token.excludeAddress(user2);
        token.transfer(user1, amount * 2);
        vm.stopPrank();

        uint256 balanceBefore = token.balanceOf(user2);
        vm.prank(user1);
        token.transfer(user2, amount);
        assertEq(token.balanceOf(user2), balanceBefore + amount);
    }

    function testFuzz_BuyTax_Calculation(uint256 amount) public {
        amount = bound(amount, 1, 1000000e18);
        
        vm.startPrank(owner);
        token.addPair(pair);
        token.setTaxWallet(taxWallet);
        token.transfer(pair, amount * 2);
        vm.stopPrank();

        uint256 expectedTax = (amount * 200) / 10000;
        uint256 expectedAmountAfterTax = amount - expectedTax;
        uint256 user2BalanceBefore = token.balanceOf(user2);
        uint256 taxWalletBalanceBefore = token.balanceOf(taxWallet);

        vm.prank(pair);
        token.transfer(user2, amount);

        assertEq(token.balanceOf(user2), user2BalanceBefore + expectedAmountAfterTax);
        assertEq(token.balanceOf(taxWallet), taxWalletBalanceBefore + expectedTax);
    }

    function testFuzz_SellTax_Calculation(uint256 amount) public {
        amount = bound(amount, 1, 1000000e18);
        
        vm.startPrank(owner);
        token.addPair(pair);
        token.setTaxWallet(taxWallet);
        token.transfer(user1, amount * 2);
        vm.stopPrank();

        uint256 expectedTax = (amount * 300) / 10000;
        uint256 expectedAmountAfterTax = amount - expectedTax;
        uint256 pairBalanceBefore = token.balanceOf(pair);
        uint256 taxWalletBalanceBefore = token.balanceOf(taxWallet);

        vm.prank(user1);
        token.transfer(pair, amount);

        assertEq(token.balanceOf(pair), pairBalanceBefore + expectedAmountAfterTax);
        assertEq(token.balanceOf(taxWallet), taxWalletBalanceBefore + expectedTax);
    }
}

