// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import "../contracts/MangoTokenSecure.sol";
// import "../contracts/MangoRouterSecure.sol";
// import "../contracts/PreSaleSecure.sol";
// import "../contracts/MangoReferral.sol";

// /**
//  * @title SecurityTests
//  * @dev Comprehensive security tests for the Mango ecosystem
//  */
// contract SecurityTests is Test {
//     MangoTokenSecure public mangoToken;
//     MangoRouterSecure public mangoRouter;
//     PreSaleSecure public preSale;
//     MangoReferral public mangoReferral;

//     address public owner;
//     address public alice;
//     address public bob;
//     address public attacker;
//     address public treasury;

//     // Mock contracts for testing
//     MockUniswapV2Factory public mockFactoryV2;
//     MockUniswapV3Factory public mockFactoryV3;
//     MockUniswapRouter public mockRouterV2;
//     MockSwapRouter02 public mockSwapRouter02;
//     MockWETH public mockWETH;

//     function setUp() public {
//         owner = address(this);
//         alice = makeAddr("alice");
//         bob = makeAddr("bob");
//         attacker = makeAddr("attacker");
//         treasury = makeAddr("treasury");

//         // Deploy mock contracts
//         _deployMockContracts();

//         // Deploy main contracts
//         _deployMainContracts();

//         // Setup initial state
//         _setupInitialState();
//     }

//     function _deployMockContracts() internal {
//         mockFactoryV2 = new MockUniswapV2Factory();
//         mockFactoryV3 = new MockUniswapV3Factory();
//         mockRouterV2 = new MockUniswapRouter();
//         mockSwapRouter02 = new MockSwapRouter02();
//         mockWETH = new MockWETH();
//     }

//     function _deployMainContracts() internal {
//         // Deploy token
//         mangoToken = new MangoTokenSecure(
//             address(mockRouterV2),
//             treasury,
//             100, // 1% max transaction
//             200  // 2% max wallet
//         );

//         // Deploy referral
//         mangoReferral = new MangoReferral();

//         // Deploy router
//         mangoRouter = new MangoRouterSecure(
//             address(mockFactoryV2),
//             address(mockFactoryV3),
//             address(mockRouterV2),
//             address(mockSwapRouter02),
//             address(mockWETH)
//         );

//         // Deploy presale
//         preSale = new PreSaleSecure(
//             address(mangoToken),
//             treasury,
//             100 ether, // max funding
//             30 days,   // duration
//             bytes32(0) // empty merkle root
//         );
//     }

//     function _setupInitialState() internal {
//         // Configure contracts
//         mangoRouter.setReferralContract(address(mangoReferral));
//         mangoReferral.addRouter(address(mangoRouter));
//         mangoReferral.addToken(address(mangoToken));

//         // Setup exclusions
//         mangoToken.setExcludedFromTax(address(mangoRouter), true);
//         mangoToken.setExcludedFromTax(address(preSale), true);

//         // Transfer tokens to presale
//         uint256 presaleAllocation = mangoToken.totalSupply() * 5 / 100;
//         mangoToken.transfer(address(preSale), presaleAllocation);

//         // Enable trading
//         mangoToken.enableTrading();

//         // Fund test accounts
//         vm.deal(alice, 100 ether);
//         vm.deal(bob, 100 ether);
//         vm.deal(attacker, 100 ether);
//     }

//     // ============ REENTRANCY TESTS ============

//     function testReentrancyProtectionInRouter() public {
//         // Deploy malicious contract
//         MaliciousContract malicious = new MaliciousContract(address(mangoRouter));
//         vm.deal(address(malicious), 10 ether);

//         // Try reentrancy attack
//         vm.expectRevert();
//         malicious.attack();
//     }

//     function testReentrancyProtectionInPresale() public {
//         // Deploy malicious presale attacker
//         MaliciousPresaleContract malicious = new MaliciousPresaleContract(address(preSale));
//         vm.deal(address(malicious), 10 ether);

//         // Try reentrancy attack on presale
//         vm.expectRevert();
//         malicious.attack();
//     }

//     // ============ SLIPPAGE PROTECTION TESTS ============

//     function testSlippageProtection() public {
//         vm.startPrank(alice);
        
//         // Mock a scenario where expected output is 1000 tokens
//         // but with 5% slippage tolerance, minimum should be 950 tokens
//         uint256 ethAmount = 1 ether;
//         uint256 slippageTolerance = 500; // 5%

//         // If actual output is less than minimum, should revert
//         vm.expectRevert(MangoRouterSecure.SlippageExceeded.selector);
//         mangoRouter.swap{value: ethAmount}(
//             address(0), // ETH
//             address(mangoToken),
//             0,
//             address(0), // no referrer
//             slippageTolerance
//         );

//         vm.stopPrank();
//     }

//     function testInvalidSlippageTolerance() public {
//         vm.startPrank(alice);
        
//         uint256 ethAmount = 1 ether;
//         uint256 invalidSlippage = 1500; // 15% - too high

//         vm.expectRevert(MangoRouterSecure.InvalidSlippageTolerance.selector);
//         mangoRouter.swap{value: ethAmount}(
//             address(0),
//             address(mangoToken),
//             0,
//             address(0),
//             invalidSlippage
//         );

//         vm.stopPrank();
//     }

//     // ============ ACCESS CONTROL TESTS ============

//     function testOnlyOwnerFunctions() public {
//         vm.startPrank(attacker);

//         // Test token owner functions
//         vm.expectRevert();
//         mangoToken.proposeTaxChange(100, 100, treasury);

//         vm.expectRevert();
//         mangoToken.pause();

//         // Test router owner functions
//         vm.expectRevert();
//         mangoRouter.setTaxFee(400);

//         vm.expectRevert();
//         mangoRouter.pause();

//         // Test presale owner functions
//         vm.expectRevert();
//         preSale.endPresale();

//         vm.expectRevert();
//         preSale.pause();

//         vm.stopPrank();
//     }

//     function testTimelockForTaxChanges() public {
//         // Propose tax change
//         mangoToken.proposeTaxChange(200, 300, treasury);

//         // Try to execute immediately - should fail
//         vm.expectRevert(MangoTokenSecure.TimelockNotReady.selector);
//         mangoToken.executeTaxChange();

//         // Fast forward time
//         vm.warp(block.timestamp + 24 hours + 1);

//         // Now should work
//         mangoToken.executeTaxChange();

//         assertEq(mangoToken.buyTax(), 200);
//         assertEq(mangoToken.sellTax(), 300);
//     }

//     // ============ OVERFLOW/UNDERFLOW TESTS ============

//     function testSafeMathProtection() public {
//         vm.startPrank(alice);

//         // Try to transfer more than balance
//         uint256 balance = mangoToken.balanceOf(alice);
//         vm.expectRevert();
//         mangoToken.transfer(bob, balance + 1);

//         vm.stopPrank();
//     }

//     function testMaxTaxLimits() public {
//         // Try to set tax higher than maximum
//         vm.expectRevert(MangoTokenSecure.TaxTooHigh.selector);
//         mangoToken.proposeTaxChange(400, 300, treasury); // 4% buy tax - too high

//         vm.expectRevert(MangoTokenSecure.TaxTooHigh.selector);
//         mangoToken.proposeTaxChange(300, 400, treasury); // 4% sell tax - too high
//     }

//     // ============ TRANSACTION LIMIT TESTS ============

//     function testTransactionLimits() public {
//         uint256 maxTx = mangoToken.maxTransactionAmount();
//         uint256 supply = mangoToken.totalSupply();
        
//         // Give alice more than max transaction
//         mangoToken.transfer(alice, maxTx + 1000 ether);

//         vm.startPrank(alice);

//         // Try to transfer more than max transaction
//         vm.expectRevert(MangoTokenSecure.ExceedsMaxTransaction.selector);
//         mangoToken.transfer(bob, maxTx + 1);

//         vm.stopPrank();
//     }

//     function testWalletLimits() public {
//         uint256 maxWallet = mangoToken.maxWalletAmount();
        
//         // Try to transfer more than max wallet
//         vm.expectRevert(MangoTokenSecure.ExceedsMaxWallet.selector);
//         mangoToken.transfer(alice, maxWallet + 1);
//     }

//     function testTransactionCooldown() public {
//         // Give alice some tokens
//         mangoToken.transfer(alice, 1000 ether);

//         vm.startPrank(alice);

//         // First transaction should work
//         mangoToken.transfer(bob, 100 ether);

//         // Second transaction immediately should fail due to cooldown
//         vm.expectRevert(MangoTokenSecure.TransactionTooFrequent.selector);
//         mangoToken.transfer(bob, 100 ether);

//         // Fast forward past cooldown
//         vm.warp(block.timestamp + 2);

//         // Now should work
//         mangoToken.transfer(bob, 100 ether);

//         vm.stopPrank();
//     }

//     // ============ BLACKLIST TESTS ============

//     function testBlacklistProtection() public {
//         // Blacklist attacker
//         mangoToken.setBlacklisted(attacker, true);

//         // Give attacker some tokens first
//         mangoToken.transfer(attacker, 1000 ether);

//         vm.startPrank(attacker);

//         // Blacklisted user cannot transfer
//         vm.expectRevert(MangoTokenSecure.Blacklisted.selector);
//         mangoToken.transfer(bob, 100 ether);

//         vm.stopPrank();

//         // Others cannot transfer to blacklisted user
//         vm.startPrank(alice);
//         mangoToken.transfer(alice, 1000 ether); // Give alice tokens

//         vm.expectRevert(MangoTokenSecure.Blacklisted.selector);
//         mangoToken.transfer(attacker, 100 ether);

//         vm.stopPrank();
//     }

//     // ============ PRESALE SECURITY TESTS ============

//     function testPresalePurchaseLimits() public {
//         vm.startPrank(alice);

//         // Try to purchase less than minimum
//         vm.expectRevert(PreSaleSecure.InsufficientPayment.selector);
//         preSale.purchaseTokens{value: 0.005 ether}(); // Less than 0.01 ETH minimum

//         // Try to purchase more than maximum
//         vm.expectRevert(PreSaleSecure.ExceedsMaxPurchase.selector);
//         preSale.purchaseTokens{value: 6 ether}(); // More than 5 ETH maximum

//         vm.stopPrank();
//     }

//     function testPresaleCooldown() public {
//         vm.startPrank(alice);

//         // First purchase should work
//         preSale.purchaseTokens{value: 1 ether}();

//         // Second purchase immediately should fail
//         vm.expectRevert(PreSaleSecure.PurchaseTooFrequent.selector);
//         preSale.purchaseTokens{value: 1 ether}();

//         // Fast forward past cooldown
//         vm.warp(block.timestamp + 61); // 1 minute + 1 second

//         // Now should work
//         preSale.purchaseTokens{value: 1 ether}();

//         vm.stopPrank();
//     }

//     // ============ EMERGENCY PAUSE TESTS ============

//     function testEmergencyPause() public {
//         // Pause all contracts
//         mangoToken.pause();
//         mangoRouter.pause();
//         preSale.pause();

//         vm.startPrank(alice);

//         // All operations should fail when paused
//         vm.expectRevert();
//         mangoToken.transfer(bob, 100 ether);

//         vm.expectRevert();
//         mangoRouter.swap{value: 1 ether}(
//             address(0),
//             address(mangoToken),
//             0,
//             address(0),
//             200
//         );

//         vm.expectRevert();
//         preSale.purchaseTokens{value: 1 ether}();

//         vm.stopPrank();

//         // Unpause and operations should work again
//         mangoToken.unpause();
//         mangoRouter.unpause();
//         preSale.unpause();

//         vm.startPrank(alice);
//         mangoToken.transfer(alice, 1000 ether); // Give alice tokens first
//         mangoToken.transfer(bob, 100 ether); // Should work now
//         vm.stopPrank();
//     }

//     // ============ GAS OPTIMIZATION TESTS ============

//     function testGasUsage() public {
//         vm.startPrank(alice);
//         mangoToken.transfer(alice, 1000 ether);

//         uint256 gasStart = gasleft();
//         mangoToken.transfer(bob, 100 ether);
//         uint256 gasUsed = gasStart - gasleft();

//         console.log("Gas used for transfer:", gasUsed);
//         assertLt(gasUsed, 100000, "Transfer gas usage too high");

//         vm.stopPrank();
//     }

//     // ============ INTEGRATION TESTS ============

//     function testFullSwapFlow() public {
//         // Setup liquidity pair
//         address pair = makeAddr("pair");
//         mockFactoryV2.setPair(address(mockWETH), address(mangoToken), pair);
//         mangoToken.addPair(pair);

//         vm.startPrank(alice);

//         // Test ETH to token swap
//         uint256 initialBalance = mangoToken.balanceOf(alice);
//         mangoRouter.swap{value: 1 ether}(
//             address(0), // ETH
//             address(mangoToken),
//             0,
//             address(0), // no referrer
//             200 // 2% slippage
//         );

//         assertGt(mangoToken.balanceOf(alice), initialBalance, "Tokens not received");

//         vm.stopPrank();
//     }
// }

// // ============ MALICIOUS CONTRACTS FOR TESTING ============

// contract MaliciousContract {
//     MangoRouterSecure public router;
//     bool public attacking = false;

//     constructor(address _router) {
//         router = MangoRouterSecure(_router);
//     }

//     function attack() external {
//         attacking = true;
//         router.swap{value: 1 ether}(
//             address(0),
//             address(0x1234), // dummy token
//             0,
//             address(0),
//             200
//         );
//     }

//     receive() external payable {
//         if (attacking) {
//             // Try to reenter
//             router.swap{value: 0.5 ether}(
//                 address(0),
//                 address(0x1234),
//                 0,
//                 address(0),
//                 200
//             );
//         }
//     }
// }

// contract MaliciousPresaleContract {
//     PreSaleSecure public presale;
//     bool public attacking = false;

//     constructor(address _presale) {
//         presale = PreSaleSecure(_presale);
//     }

//     function attack() external {
//         attacking = true;
//         presale.purchaseTokens{value: 1 ether}();
//     }

//     receive() external payable {
//         if (attacking && address(presale).balance > 0) {
//             // Try to reenter
//             presale.purchaseTokens{value: 0.5 ether}();
//         }
//     }
// }

// // ============ MOCK CONTRACTS ============

// contract MockUniswapV2Factory {
//     mapping(address => mapping(address => address)) public pairs;

//     function getPair(address tokenA, address tokenB) external view returns (address) {
//         return pairs[tokenA][tokenB];
//     }

//     function setPair(address tokenA, address tokenB, address pair) external {
//         pairs[tokenA][tokenB] = pair;
//         pairs[tokenB][tokenA] = pair;
//     }
// }

// contract MockUniswapV3Factory {
//     mapping(address => mapping(address => mapping(uint24 => address))) public pools;

//     function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address) {
//         return pools[tokenA][tokenB][fee];
//     }

//     function setPool(address tokenA, address tokenB, uint24 fee, address pool) external {
//         pools[tokenA][tokenB][fee] = pool;
//         pools[tokenB][tokenA][fee] = pool;
//     }
// }

// contract MockUniswapRouter {
//     function getAmountsOut(uint256 amountIn, address[] memory path) 
//         external 
//         pure 
//         returns (uint256[] memory amounts) 
//     {
//         amounts = new uint256[](path.length);
//         amounts[0] = amountIn;
//         for (uint256 i = 1; i < path.length; i++) {
//             amounts[i] = amountIn * 2; // Mock 2:1 ratio
//         }
//     }

//     function swapExactETHForTokens(
//         uint256 amountOutMin,
//         address[] calldata path,
//         address to,
//         uint256 deadline
//     ) external payable returns (uint256[] memory amounts) {
//         amounts = new uint256[](2);
//         amounts[0] = msg.value;
//         amounts[1] = msg.value * 2;
//         // Mock transfer - in real test, would transfer mock tokens
//     }

//     function swapExactTokensForETH(
//         uint256 amountIn,
//         uint256 amountOutMin,
//         address[] calldata path,
//         address to,
//         uint256 deadline
//     ) external returns (uint256[] memory amounts) {
//         amounts = new uint256[](2);
//         amounts[0] = amountIn;
//         amounts[1] = amountIn / 2;
//         // Mock transfer ETH
//         payable(to).transfer(amounts[1]);
//     }

//     function swapExactTokensForTokens(
//         uint256 amountIn,
//         uint256 amountOutMin,
//         address[] calldata path,
//         address to,
//         uint256 deadline
//     ) external returns (uint256[] memory amounts) {
//         amounts = new uint256[](2);
//         amounts[0] = amountIn;
//         amounts[1] = amountIn * 2;
//         // Mock transfer - in real test, would transfer mock tokens
//     }

//     receive() external payable {}
// }

// contract MockSwapRouter02 {
//     struct ExactInputSingleParams {
//         address tokenIn;
//         address tokenOut;
//         uint24 fee;
//         address recipient;
//         uint256 amountIn;
//         uint256 amountOutMinimum;
//         uint160 sqrtPriceLimitX96;
//     }

//     function exactInputSingle(ExactInputSingleParams calldata params)
//         external
//         payable
//         returns (uint256 amountOut)
//     {
//         amountOut = params.amountIn * 2; // Mock 2:1 ratio
//         // Mock transfer - in real test, would transfer tokens
//     }
// }

// contract MockWETH {
//     mapping(address => uint256) public balanceOf;

//     function withdraw(uint256 amount) external {
//         require(balanceOf[msg.sender] >= amount, "Insufficient balance");
//         balanceOf[msg.sender] -= amount;
//         payable(msg.sender).transfer(amount);
//     }

//     function deposit() external payable {
//         balanceOf[msg.sender] += msg.value;
//     }

//     receive() external payable {
//         deposit();
//     }
// }