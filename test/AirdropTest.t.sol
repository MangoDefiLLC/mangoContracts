// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Airdrop} from "../contracts/airDrop.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IMangoErrors} from "../contracts/interfaces/IMangoErrors.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000e18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AirdropTest is Test {
    Airdrop public airdrop;
    MockERC20 public token;
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public nonWhitelisted;

    Airdrop.holder[] public holders;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);
        nonWhitelisted = address(0x999);

        // Deploy contracts
        airdrop = new Airdrop();
        token = new MockERC20("Test Token", "TEST");

        // Setup: owner is whitelisted by default, transfer tokens to airdrop contract
        token.transfer(address(airdrop), 10000e18);

        // Setup holders array
        holders.push(Airdrop.holder(user1, 1000e18));
        holders.push(Airdrop.holder(user2, 2000e18));
        holders.push(Airdrop.holder(user3, 3000e18));
    }

    // ============ Unit Tests ============

    function test_Constructor_WhitelistsDeployer() public {
        assertTrue(airdrop.whiteList(owner));
    }

    function test_AirDrop_Success() public {
        uint256 balanceBefore1 = token.balanceOf(user1);
        uint256 balanceBefore2 = token.balanceOf(user2);
        uint256 balanceBefore3 = token.balanceOf(user3);

        airdrop.airDrop(holders, address(token));

        assertEq(token.balanceOf(user1), balanceBefore1 + 1000e18);
        assertEq(token.balanceOf(user2), balanceBefore2 + 2000e18);
        assertEq(token.balanceOf(user3), balanceBefore3 + 3000e18);
    }

    function test_AirDrop_RevertsWhenNotWhitelisted() public {
        vm.prank(nonWhitelisted);
        vm.expectRevert(IMangoErrors.NotAuthorized.selector);
        airdrop.airDrop(holders, address(token));
    }

    function test_AirDrop_RevertsWhenInsufficientBalance() public {
        // Create holders with more tokens than contract has
        Airdrop.holder[] memory largeHolders = new Airdrop.holder[](1);
        largeHolders[0] = Airdrop.holder(user1, 20000e18); // More than contract has

        vm.expectRevert(Airdrop.needMoreBalance.selector);
        airdrop.airDrop(largeHolders, address(token));
    }

    function test_AirDrop_EmptyList() public {
        Airdrop.holder[] memory emptyHolders = new Airdrop.holder[](0);
        
        // Should not revert, just do nothing
        airdrop.airDrop(emptyHolders, address(token));
    }

    function test_AirDrop_SingleHolder() public {
        Airdrop.holder[] memory singleHolder = new Airdrop.holder[](1);
        singleHolder[0] = Airdrop.holder(user1, 500e18);

        airdrop.airDrop(singleHolder, address(token));
        assertEq(token.balanceOf(user1), 500e18);
    }

    function test_AddToWhitelist_Success() public {
        assertFalse(airdrop.whiteList(user1));
        airdrop.addToWhitelist(user1);
        assertTrue(airdrop.whiteList(user1));
    }

    function test_AddToWhitelist_RevertsWhenNotWhitelisted() public {
        vm.prank(nonWhitelisted);
        vm.expectRevert(IMangoErrors.NotAuthorized.selector);
        airdrop.addToWhitelist(user1);
    }

    function test_AddToWhitelist_RevertsWhenZeroAddress() public {
        vm.expectRevert(IMangoErrors.ValueIsZero.selector);
        airdrop.addToWhitelist(address(0));
    }

    function test_RemoveFromWhitelist_Success() public {
        // Add user1 first
        airdrop.addToWhitelist(user1);
        assertTrue(airdrop.whiteList(user1));

        // Remove user1
        airdrop.removeFromWhitelist(user1);
        assertFalse(airdrop.whiteList(user1));
    }

    function test_RemoveFromWhitelist_RevertsWhenNotWhitelisted() public {
        vm.prank(nonWhitelisted);
        vm.expectRevert(IMangoErrors.NotAuthorized.selector);
        airdrop.removeFromWhitelist(user1);
    }

    function test_WithdrawToken_Success() public {
        uint256 amount = 1000e18;
        uint256 balanceBefore = token.balanceOf(owner);

        airdrop.withdrawToken(address(token), amount);

        assertEq(token.balanceOf(owner), balanceBefore + amount);
    }

    function test_WithdrawToken_RevertsWhenNotWhitelisted() public {
        vm.prank(nonWhitelisted);
        vm.expectRevert();
        airdrop.withdrawToken(address(token), 1000e18);
    }

    // ============ Fuzz Tests ============

    function testFuzz_AirDrop_VariousAmounts(uint256 amount1, uint256 amount2, uint256 amount3) public {
        // Bound amounts to reasonable values
        amount1 = bound(amount1, 1, 1000e18);
        amount2 = bound(amount2, 1, 1000e18);
        amount3 = bound(amount3, 1, 1000e18);

        uint256 total = amount1 + amount2 + amount3;
        
        // Ensure contract has enough balance
        if (token.balanceOf(address(airdrop)) < total) {
            token.mint(address(airdrop), total - token.balanceOf(address(airdrop)) + 1);
        }

        Airdrop.holder[] memory fuzzHolders = new Airdrop.holder[](3);
        fuzzHolders[0] = Airdrop.holder(user1, amount1);
        fuzzHolders[1] = Airdrop.holder(user2, amount2);
        fuzzHolders[2] = Airdrop.holder(user3, amount3);

        uint256 balanceBefore1 = token.balanceOf(user1);
        uint256 balanceBefore2 = token.balanceOf(user2);
        uint256 balanceBefore3 = token.balanceOf(user3);

        airdrop.airDrop(fuzzHolders, address(token));

        assertEq(token.balanceOf(user1), balanceBefore1 + amount1);
        assertEq(token.balanceOf(user2), balanceBefore2 + amount2);
        assertEq(token.balanceOf(user3), balanceBefore3 + amount3);
    }

    function testFuzz_AddToWhitelist_NonZeroAddress(address addr) public {
        vm.assume(addr != address(0));
        vm.assume(addr != owner);

        assertFalse(airdrop.whiteList(addr));
        airdrop.addToWhitelist(addr);
        assertTrue(airdrop.whiteList(addr));
    }

    // ============ Gas Benchmarks ============

    function test_GasBenchmark_AirDrop_SmallBatch() public {
        Airdrop.holder[] memory smallHolders = new Airdrop.holder[](3);
        smallHolders[0] = Airdrop.holder(user1, 100e18);
        smallHolders[1] = Airdrop.holder(user2, 200e18);
        smallHolders[2] = Airdrop.holder(user3, 300e18);

        uint256 gasBefore = gasleft();
        airdrop.airDrop(smallHolders, address(token));
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for 3-holder airdrop:", gasUsed);
        assertLt(gasUsed, 200000); // Should be reasonable
    }

    function test_GasBenchmark_AirDrop_LargeBatch() public {
        // Create 10 holders
        Airdrop.holder[] memory largeHolders = new Airdrop.holder[](10);
        for (uint256 i = 0; i < 10; i++) {
            largeHolders[i] = Airdrop.holder(address(uint160(i + 100)), 100e18);
        }

        // Ensure contract has enough tokens
        token.mint(address(airdrop), 10000e18);

        uint256 gasBefore = gasleft();
        airdrop.airDrop(largeHolders, address(token));
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for 10-holder airdrop:", gasUsed);
    }

    // ============ Edge Cases ============

    function test_AirDrop_SameAddressMultipleTimes() public {
        Airdrop.holder[] memory duplicateHolders = new Airdrop.holder[](3);
        duplicateHolders[0] = Airdrop.holder(user1, 100e18);
        duplicateHolders[1] = Airdrop.holder(user1, 200e18);
        duplicateHolders[2] = Airdrop.holder(user1, 300e18);

        airdrop.airDrop(duplicateHolders, address(token));
        assertEq(token.balanceOf(user1), 600e18); // Sum of all amounts
    }

    function test_AirDrop_ZeroAmount() public {
        Airdrop.holder[] memory zeroHolders = new Airdrop.holder[](1);
        zeroHolders[0] = Airdrop.holder(user1, 0);

        // Should not revert, just transfer 0
        airdrop.airDrop(zeroHolders, address(token));
        assertEq(token.balanceOf(user1), 0);
    }

    function test_RemoveFromWhitelist_NotInList() public {
        // Removing non-whitelisted address should not revert
        assertFalse(airdrop.whiteList(user1));
        airdrop.removeFromWhitelist(user1);
        assertFalse(airdrop.whiteList(user1));
    }
}

