// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/preSale.sol";
import "../contracts/interface/IERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) IERC20(name, symbol) {
        _mint(msg.sender, 100_000_000_000 * 10**18); // Mint 100B tokens
    }
}

contract PresaleTest is Test {
    Presale public presale;
    MockERC20 public token;
    address public owner = address(0x123);
    address public buyer1 = address(0x456);
    address public buyer2 = address(0x789);
    address public uniswapRouter = address(0x999);
    address public weth = address(0x888);

    uint256 public constant STAGE1_PRICE = 0.00000625 ether;
    uint256 public constant STAGE2_PRICE = 0.000009375 ether;
    uint256 public constant STAGE3_PRICE = 0.0000125 ether;

    uint256 public constant STAGE1_LIMIT = 20_000_000_000 * 10**18;
    uint256 public constant STAGE2_LIMIT = 35_000_000_000 * 10**18;
    uint256 public constant TOTAL_PRESALE_TOKENS = 50_000_000_000 * 10**18;

    function setUp() public {
        vm.startPrank(owner);
        token = new MockERC20("TestToken", "TT");
        presale = new Presale(address(token), uniswapRouter, weth);
        vm.stopPrank();

        // Transfer presale tokens to the presale contract
        vm.prank(owner);
        token.transfer(address(presale), TOTAL_PRESALE_TOKENS);
    }

    // Test buying tokens in Stage 1
    function testBuyTokensStage1() public {
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        presale.buyTokens{value: 1 ether}();

        uint256 expectedTokens = 1 ether / STAGE1_PRICE;
        assertEq(token.balanceOf(buyer1), expectedTokens);
        assertEq(presale.tokensSold(), expectedTokens);
        assertEq(presale.totalEthRaised(), 1 ether);
    }

    // Test buying tokens in Stage 2
    function testBuyTokensStage2() public {
        // Fill up Stage 1
        vm.deal(buyer1, STAGE1_LIMIT * STAGE1_PRICE);
        vm.prank(buyer1);
        presale.buyTokens{value: STAGE1_LIMIT * STAGE1_PRICE}();

        // Buy in Stage 2
        vm.deal(buyer2, 1 ether);
        vm.prank(buyer2);
        presale.buyTokens{value: 1 ether}();

        uint256 expectedTokens = 1 ether / STAGE2_PRICE;
        assertEq(token.balanceOf(buyer2), expectedTokens);
        assertEq(presale.tokensSold(), STAGE1_LIMIT + expectedTokens);
        assertEq(presale.totalEthRaised(), (STAGE1_LIMIT * STAGE1_PRICE) + 1 ether);
    }

    // Test buying tokens in Stage 3
    function testBuyTokensStage3() public {
        // Fill up Stage 1 and Stage 2
        vm.deal(buyer1, STAGE2_LIMIT * STAGE1_PRICE);
        vm.prank(buyer1);
        presale.buyTokens{value: STAGE2_LIMIT * STAGE1_PRICE}();

        // Buy in Stage 3
        vm.deal(buyer2, 1 ether);
        vm.prank(buyer2);
        presale.buyTokens{value: 1 ether}();

        uint256 expectedTokens = 1 ether / STAGE3_PRICE;
        assertEq(token.balanceOf(buyer2), expectedTokens);
        assertEq(presale.tokensSold(), STAGE2_LIMIT + expectedTokens);
        assertEq(presale.totalEthRaised(), (STAGE2_LIMIT * STAGE1_PRICE) + 1 ether);
    }

    // Test buying tokens after presale ends
    function testBuyTokensAfterPresaleEnds() public {
        vm.prank(owner);
        presale.endPresale();

        vm.deal(buyer1, 1 ether);
        vm.expectRevert("Presale ended");
        vm.prank(buyer1);
        presale.buyTokens{value: 1 ether}();
    }

    // Test buying tokens with insufficient ETH
    function testBuyTokensInsufficientETH() public {
        vm.deal(buyer1, 0);
        vm.expectRevert("Send ETH to buy tokens");
        vm.prank(buyer1);
        presale.buyTokens{value: 0}();
    }

    // Test exceeding max ETH limit
    function testExceedMaxETH() public {
        vm.deal(buyer1, 301 ether);
        vm.expectRevert("Exceeds max ETH limit");
        vm.prank(buyer1);
        presale.buyTokens{value: 301 ether}();
    }

    // Test exceeding total presale token limit
    function testExceedTotalPresaleTokens() public {
        vm.deal(buyer1, STAGE1_LIMIT * STAGE1_PRICE);
        vm.prank(buyer1);
        presale.buyTokens{value: STAGE1_LIMIT * STAGE1_PRICE}();

        vm.deal(buyer2, STAGE2_LIMIT * STAGE2_PRICE);
        vm.prank(buyer2);
        presale.buyTokens{value: STAGE2_LIMIT * STAGE2_PRICE}();

        vm.deal(buyer1, 1 ether);
        vm.expectRevert("Not enough tokens left");
        vm.prank(buyer1);
        presale.buyTokens{value: 1 ether}();
    }

    // Test event emission
    function testEventEmission() public {
        vm.deal(buyer1, 1 ether);
        vm.expectEmit(true, true, true, true);
        emit TokensPurchased(buyer1, 1 ether, 1 ether / STAGE1_PRICE);
        vm.prank(buyer1);
        presale.buyTokens{value: 1 ether}();
    }

    // Test ETH withdrawal (if added in the future)
    function testWithdrawETH() public {
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        presale.buyTokens{value: 1 ether}();

        vm.prank(owner);
        presale.endPresale();

        uint256 contractBalanceBefore = address(presale).balance;
        vm.prank(owner);
        presale.withdrawETH();

        assertEq(address(presale).balance, 0);
        assertEq(owner.balance, contractBalanceBefore);
    }
}