// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/MangoTokenSecure.sol";
import "../contracts/MangoRouterSecure.sol";
import "../contracts/PreSaleSecure.sol";
import "../contracts/MangoReferral.sol";

/**
 * @title DeploySecure
 * @dev Secure deployment script for Mango ecosystem with proper verification and configuration
 */
contract DeploySecure is Script {
    // Network configurations
    struct NetworkConfig {
        address factoryV2;
        address factoryV3;
        address routerV2;
        address swapRouter02;
        address weth;
        string name;
    }

    // Deployment configuration
    struct DeployConfig {
        uint256 maxTransactionPercent; // 100 = 1%
        uint256 maxWalletPercent;      // 200 = 2%
        uint256 presaleDuration;       // seconds
        uint256 maxFunding;           // wei
        address treasury;             // treasury address
        bytes32 vipMerkleRoot;       // VIP merkle root
    }

    // Deployed contracts
    MangoTokenSecure public mangoToken;
    MangoRouterSecure public mangoRouter;
    PreSaleSecure public preSale;
    MangoReferral public mangoReferral;

    // Events
    event ContractDeployed(string indexed contractName, address indexed contractAddress);
    event DeploymentCompleted(
        address indexed token,
        address indexed router,
        address indexed presale,
        address referral
    );

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== MANGO SECURE DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Balance:", deployer.balance);

        // Get network configuration
        NetworkConfig memory config = getNetworkConfig();
        console.log("Network:", config.name);
        
        // Get deployment configuration
        DeployConfig memory deployConfig = getDeployConfig(deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy MangoToken
        _deployMangoToken(config, deployConfig);

        // Step 2: Deploy MangoReferral
        _deployMangoReferral(config);

        // Step 3: Deploy MangoRouter
        _deployMangoRouter(config);

        // Step 4: Deploy PreSale
        _deployPreSale(deployConfig);

        // Step 5: Configure contracts
        _configureContracts(config, deployConfig);

        vm.stopBroadcast();

        // Step 6: Verify deployments
        _verifyDeployments();

        // Step 7: Output deployment summary
        _outputDeploymentSummary();

        emit DeploymentCompleted(
            address(mangoToken),
            address(mangoRouter),
            address(preSale),
            address(mangoReferral)
        );
    }

    function _deployMangoToken(NetworkConfig memory config, DeployConfig memory deployConfig) internal {
        console.log("\n--- Deploying MangoTokenSecure ---");
        
        mangoToken = new MangoTokenSecure(
            config.routerV2,
            deployConfig.treasury,
            deployConfig.maxTransactionPercent,
            deployConfig.maxWalletPercent
        );

        console.log("MangoTokenSecure deployed at:", address(mangoToken));
        emit ContractDeployed("MangoTokenSecure", address(mangoToken));

        // Verify token deployment
        require(mangoToken.totalSupply() == 100_000_000_000 * 10**18, "Invalid total supply");
        require(mangoToken.owner() == msg.sender, "Invalid owner");
        console.log("✓ Token deployment verified");
    }

    function _deployMangoReferral(NetworkConfig memory config) internal {
        console.log("\n--- Deploying MangoReferral ---");
        
        mangoReferral = new MangoReferral();

        console.log("MangoReferral deployed at:", address(mangoReferral));
        emit ContractDeployed("MangoReferral", address(mangoReferral));

        // Configure referral system
        mangoReferral.addToken(address(mangoToken));
        console.log("✓ Referral deployment verified");
    }

    function _deployMangoRouter(NetworkConfig memory config) internal {
        console.log("\n--- Deploying MangoRouterSecure ---");
        
        mangoRouter = new MangoRouterSecure(
            config.factoryV2,
            config.factoryV3,
            config.routerV2,
            config.swapRouter02,
            config.weth
        );

        console.log("MangoRouterSecure deployed at:", address(mangoRouter));
        emit ContractDeployed("MangoRouterSecure", address(mangoRouter));

        // Verify router deployment
        require(address(mangoRouter.factoryV2()) == config.factoryV2, "Invalid factoryV2");
        require(address(mangoRouter.factoryV3()) == config.factoryV3, "Invalid factoryV3");
        require(address(mangoRouter.weth()) == config.weth, "Invalid WETH");
        console.log("✓ Router deployment verified");
    }

    function _deployPreSale(DeployConfig memory deployConfig) internal {
        console.log("\n--- Deploying PreSaleSecure ---");
        
        // Calculate presale token allocation (5% of total supply)
        uint256 presaleAllocation = mangoToken.totalSupply() * 5 / 100;
        
        preSale = new PreSaleSecure(
            address(mangoToken),
            deployConfig.treasury,
            deployConfig.maxFunding,
            deployConfig.presaleDuration,
            deployConfig.vipMerkleRoot
        );

        console.log("PreSaleSecure deployed at:", address(preSale));
        emit ContractDeployed("PreSaleSecure", address(preSale));

        // Transfer tokens to presale contract
        mangoToken.transfer(address(preSale), presaleAllocation);
        console.log("✓ Transferred", presaleAllocation / 10**18, "tokens to presale");
        console.log("✓ Presale deployment verified");
    }

    function _configureContracts(NetworkConfig memory config, DeployConfig memory deployConfig) internal {
        console.log("\n--- Configuring Contracts ---");

        // Configure router with referral contract
        mangoRouter.setReferralContract(address(mangoReferral));
        console.log("✓ Router configured with referral contract");

        // Add router to referral system
        mangoReferral.addRouter(address(mangoRouter));
        console.log("✓ Router added to referral system");

        // Configure token exclusions
        mangoToken.setExcludedFromTax(address(mangoRouter), true);
        mangoToken.setExcludedFromTax(address(preSale), true);
        mangoToken.setExcludedFromTax(address(mangoReferral), true);
        console.log("✓ Token exclusions configured");

        // Set router as authorized caller
        mangoRouter.setAuthorizedCaller(address(preSale), true);
        console.log("✓ Router authorization configured");

        console.log("✓ All contracts configured successfully");
    }

    function _verifyDeployments() internal view {
        console.log("\n--- Verifying Deployments ---");

        // Verify all contracts are deployed
        require(address(mangoToken).code.length > 0, "MangoToken not deployed");
        require(address(mangoRouter).code.length > 0, "MangoRouter not deployed");
        require(address(preSale).code.length > 0, "PreSale not deployed");
        require(address(mangoReferral).code.length > 0, "MangoReferral not deployed");

        // Verify token configuration
        require(mangoToken.isExcludedFromTax(address(mangoRouter)), "Router not excluded from tax");
        require(mangoToken.isExcludedFromTax(address(preSale)), "PreSale not excluded from tax");

        // Verify router configuration
        require(address(mangoRouter.mangoReferral()) == address(mangoReferral), "Referral not set in router");

        // Verify referral configuration
        require(mangoReferral.supportedTokens(address(mangoToken)), "Token not added to referral");
        require(mangoReferral.authorizedRouters(address(mangoRouter)), "Router not authorized in referral");

        console.log("✓ All verifications passed");
    }

    function _outputDeploymentSummary() internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("MangoTokenSecure:    ", address(mangoToken));
        console.log("MangoRouterSecure:   ", address(mangoRouter));
        console.log("PreSaleSecure:       ", address(preSale));
        console.log("MangoReferral:       ", address(mangoReferral));
        
        console.log("\n=== CONTRACT VERIFICATION COMMANDS ===");
        console.log("forge verify-contract", address(mangoToken), "contracts/MangoTokenSecure.sol:MangoTokenSecure");
        console.log("forge verify-contract", address(mangoRouter), "contracts/MangoRouterSecure.sol:MangoRouterSecure");
        console.log("forge verify-contract", address(preSale), "contracts/PreSaleSecure.sol:PreSaleSecure");
        console.log("forge verify-contract", address(mangoReferral), "contracts/MangoReferral.sol:MangoReferral");

        console.log("\n=== POST-DEPLOYMENT CHECKLIST ===");
        console.log("1. ✓ Enable trading: mangoToken.enableTrading()");
        console.log("2. ✓ Set up liquidity pools");
        console.log("3. ✓ Configure router with pools: mangoRouter.addPair()");
        console.log("4. ✓ Set up VIP whitelist for presale");
        console.log("5. ✓ Test all functions on testnet");
        console.log("6. ✓ Get security audit before mainnet");
    }

    function getNetworkConfig() internal view returns (NetworkConfig memory) {
        uint256 chainId = block.chainid;
        
        if (chainId == 11155111) {
            // Sepolia testnet
            return NetworkConfig({
                factoryV2: 0xF62c03E08ada871A0bEb309762E260a7a6a880E6,
                factoryV3: 0x0227628f3F023bb0B980b67D528571c95c6DaC1c,
                routerV2: 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3,
                swapRouter02: 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E,
                weth: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,
                name: "Sepolia"
            });
        } else if (chainId == 8453) {
            // Base mainnet
            return NetworkConfig({
                factoryV2: 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6,
                factoryV3: 0x33128a8fC17869897dcE68Ed026d694621f6FDfD,
                routerV2: 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24,
                swapRouter02: 0x2626664c2603336E57B271c5C0b26F421741e481,
                weth: 0x4200000000000000000000000000000000000006,
                name: "Base"
            });
        } else if (chainId == 84532) {
            // Base Sepolia
            return NetworkConfig({
                factoryV2: 0x4648a43B2C14Da09FdF82B161150d3F634f40491,
                factoryV3: 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24,
                routerV2: 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4,
                swapRouter02: 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4,
                weth: 0x4200000000000000000000000000000000000006,
                name: "Base Sepolia"
            });
        } else {
            revert("Unsupported network");
        }
    }

    function getDeployConfig(address deployer) internal pure returns (DeployConfig memory) {
        // Default deployment configuration
        return DeployConfig({
            maxTransactionPercent: 100,    // 1% of total supply
            maxWalletPercent: 200,         // 2% of total supply
            presaleDuration: 30 days,      // 30 days presale
            maxFunding: 337.5 ether,       // Maximum funding goal
            treasury: deployer,            // Use deployer as initial treasury
            vipMerkleRoot: bytes32(0)      // Empty merkle root (to be set later)
        });
    }

    // Helper function to calculate contract addresses before deployment
    function predictContractAddresses() external view returns (
        address tokenAddress,
        address routerAddress,
        address presaleAddress,
        address referralAddress
    ) {
        address deployer = msg.sender;
        uint256 nonce = vm.getNonce(deployer);
        
        tokenAddress = computeCreateAddress(deployer, nonce);
        routerAddress = computeCreateAddress(deployer, nonce + 1);
        presaleAddress = computeCreateAddress(deployer, nonce + 2);
        referralAddress = computeCreateAddress(deployer, nonce + 3);
    }

    // Emergency deployment recovery
    function emergencyRecovery(address token, address router, address presale, address referral) external {
        require(msg.sender == tx.origin, "Only EOA");
        
        mangoToken = MangoTokenSecure(token);
        mangoRouter = MangoRouterSecure(router);
        preSale = PreSaleSecure(presale);
        mangoReferral = MangoReferral(referral);
        
        console.log("Emergency recovery completed");
        _outputDeploymentSummary();
    }
}