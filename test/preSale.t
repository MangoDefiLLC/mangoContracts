// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/preSale.sol";
import "../contracts/mangoMulticall.sol";
import "../contracts/interfaces/IERC20.sol";
import "../contracts/interfaces/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 100_000_000_000 * 10**18); // Mint 100B tokens
    }
}

contract PresaleTest is Test {
    Presale public presale;
    MockERC20 public token;
    MangoMultiCall public multicall;
    uint256 public TOTAL_PRESALE_TOKENS = 60_000_000_000 * 10**18;//50 billion
    address public owner;
    address public buyer1 = address(0x456);
    address public buyer2 = address(0x789);
    address public uniswapRouter = address(0x999);
    address public weth = address(0x888);

    // Corrected prices in wei (1 ETH = $1800)
    uint256 public constant STAGE1_PRICE = 10_000_000_000 wei; // $0.000017 (7e9 wei)
    uint256 public constant STAGE2_PRICE = 15_000_000_000 wei; // $0.000019 (9e9 wei)
 

    // Adjusted stage limits
    uint256 public constant STAGE1_LIMIT = 13_500_000_000 * 10**18; // 13.5B tokens
    uint256 public constant STAGE2_LIMIT = 13_500_000_000 * 10**18; // 13.5B tokens
    
    function setUp() public {
        owner = msg.sender;
        token = new MockERC20("TestToken", "TT");
        console.log('token total balance',IERC20(token).balanceOf(address(this)));
        multicall = new MangoMultiCall();
        presale = new Presale(address(token));
        // Transfer presale tokens to the presale contract
        
        token.approve(address(presale),token.balanceOf(address(this)));//pre sale amount
        presale.depositTokens(address(token),TOTAL_PRESALE_TOKENS);
    }

    // Test buying tokens in Stage 1
    function testBuyTokensStage1() public {
        // Buy in Stage 2
        vm.deal(buyer1, 1 ether);
        vm.startPrank(buyer1);
        uint256 totalTokens = IERC20(token).balanceOf(address(this));
        console.log('balance',address(this).balance);
        //call pre sale contract buyTokens function
        presale.buyTokens{value: 1 ether}();

        uint256 expectedTokens = 1 ether / STAGE1_PRICE;
        console.log('expected tokens in stage1 buy',expectedTokens);
        assertEq(token.balanceOf(buyer1), expectedTokens,'1');
        //assertEq(presale.tokensSold(), expectedTokens,'2');
        console.log('pre sale tokens sold',presale.tokensSold());
        //assertEq(presale.totalEthRaised(), 1 ether);
        console.log('pre sale raised',presale.totalEthRaised());
       vm.stopPrank();
        console.log('balance before withdrawal',address(this).balance);
        uint256 balance = presale.withdrawETH();
        console.log('balance after withdrawal',address(this).balance);
        //console.log('prsale balance after withdrawal',)
    }

    // Test buying tokens in Stage 2
    function testBuyTokensStage2() public {
        // Fill up Stage 1
        //stage 1- 96k
        //stage 2 - 122k
        //stage 3 - 123k
        //stage 123k
        uint256 stage1Eth = (STAGE1_LIMIT * STAGE1_PRICE) / 1e18; // Correct ETH amount
        uint256 stage2Eth = (STAGE2_LIMIT * STAGE2_PRICE) / 1e18; // Correct ETH amount
        console.log('stage 1 total eth',stage1Eth);
        console.log('stage 2 total eth',stage2Eth);
        console.log('final eth amount',stage1Eth+stage2Eth);
        vm.deal(buyer1, stage1Eth+1e18);
        vm.prank(buyer1);
        presale.buyTokens{value: stage1Eth}();
        console.log('tokens before buy',token.balanceOf(buyer2));

        // Buy in Stage 2
        vm.deal(buyer2, 1 ether);
        vm.prank(buyer2);
        presale.buyTokens{value: 1 ether}();
        console.log('tokens after buy',token.balanceOf(buyer2));
        uint256 expectedTokens = 1 ether / STAGE2_PRICE;
        assertEq(token.balanceOf(buyer2), expectedTokens, "Buyer 2 token balance mismatch");
        assertEq(presale.tokensSold(), STAGE1_LIMIT + expectedTokens, "Tokens sold mismatch");
        //assertEq(presale.totalEthRaised(), stage1Eth + 1 ether, "Total ETH raised mismatch");//14,200,000,000

        console.log("Total ETH raised in Stage 2:", presale.totalEthRaised());
        console.log('presale token amount',IERC20(token).balanceOf(address(presale)));
    }
    fallback() external payable{}
}
   /**
    // Test buying tokens in Stage 3
    function testBuyTokensStage3() public {
        // Fill up Stage 1 and Stage 2
        vm.deal(buyer1, STAGE2_LIMIT * STAGE2_PRICE);
        vm.prank(buyer1);
        presale.buyTokens{value: STAGE2_LIMIT * STAGE2_PRICE}();

        // Buy in Stage 3
        vm.deal(buyer2, 1 ether);
        vm.prank(buyer2);
        presale.buyTokens{value: 1 ether}();

        uint256 expectedTokens = 1 ether / STAGE3_PRICE;
        assertEq(token.balanceOf(buyer2), expectedTokens);
        assertEq(presale.tokensSold(), STAGE2_LIMIT + STAGE2_PRICE);
        assertEq(presale.totalEthRaised(), (STAGE2_LIMIT * STAGE2_PRICE) + 1 ether);
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
        //emit TokensPurchased(buyer1, 1 ether, 1 ether / STAGE1_PRICE);
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
    } */
//}