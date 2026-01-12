// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Deploy_Script} from "./deployScript.s.sol";
import {MangoRouter002} from "../contracts/mangoRouter001.sol";
import {MangoReferral} from "../contracts/mangoReferral.sol";
import {Mango_Manager} from "../contracts/manager.sol";
import {IRouterV2} from "../contracts/interfaces/IRouterV2.sol";
import {IMangoStructs} from "../contracts/interfaces/IMangoStructs.sol";

/**
 * @title DeployNonBase
 * @notice Deploy Mango Router, Referral and Manager on non-base chains (BSC / Arbitrum / Sepolia ..)
 *
 * Usage:
 * 1) Export RPC urls used by your deploy script (example names):
 *    BASE_RPC, BSC_RPC, ARBITRUM_RPC, SEPOLIA_RPC
 * 2) Optionally set MANGO_TOKEN_BSC, MANGO_TOKEN_ARBITRUM, MANGO_TOKEN_SEPOLIA to point to
 *    the existing MANGO token address on each chain. If a token address is missing the script
 *    will skip deploying referral/manager for that chain.
 * 3) Export PVK env var with the deployer private key used for broadcasting.
 *
 * Run with forge:
 * forge script script/deployNonBase.s.sol:DeployNonBase --broadcast -vvvv
 */
contract DeployNonBase is Script {

    function run() public {
        // Chains to deploy to (non-base)
        string[4] memory chainKeys = ["BSC", "ARBITRUM", "SEPOLIA","TRON"];
        string[4] memory rpcEnvNames = ["BSC_RPC", "ARBITRUM_RPC", "SEPOLIA_RPC","TRON_RPC"];

    // Read private key for broadcasting (optional)
    // If PVK is not set the script will run in dry-run mode (no broadcast).
    uint256 pvk = vm.envUint("PVK");
    bool broadcastEnabled = pvk != 0;

        // Instantiate helper deploy script to reuse the chain variable mapping logic
        Deploy_Script ds = new Deploy_Script();
        // Initialize deploy script (reads BASE_RPC, BSC_RPC, etc. into state)
        ds.setUp();

        for (uint256 i = 0; i < rpcEnvNames.length; ) {
            string memory rpcEnv = rpcEnvNames[i];
            string memory chainKey = chainKeys[i];

            // Try to read RPC URL for this chain. If missing, skip.
            string memory rpc = vm.envOr(rpcEnv, string(abi.encodePacked("")));
            if (bytes(rpc).length == 0) {
                console.log("Skipping %s: no RPC env var (%s)", chainKey, rpcEnv);
                unchecked { ++i; }
                continue;
            }

            console.log("\n=== Deploying on %s ===", chainKey);
            console.log("Using RPC env %s -> %s", rpcEnv, rpc);

            // select fork for this chain RPC and configure parameters using deploy script mapping
            vm.createSelectFork(rpc);
            ds.setVariablesByChain(rpc);

            // Read params from Deploy_Script
            (
                address factoryV2,
                address factoryV3,
                address routerV2,
                address swapRouter02,
                address weth,
                uint256 taxFee,
                uint256 referralFee
            ) = ds.params();

            // prefer USDC address provided by Deploy_Script; fall back to USDC_<CHAIN> env var
            address usdc = ds.usdc();
            if (usdc == address(0)) {
                string memory usdcEnvKey = string.concat("USDC_", chainKey);
                usdc = vm.envOr(usdcEnvKey, address(0));
            }
            // Start broadcast for deploying contracts if PVK is provided.
            if (broadcastEnabled) {
                vm.startBroadcast(pvk);
            } else {
                console.log("PVK not set: running in dry-run mode (no broadcast). Contracts will not be published to a network.");
            }

            // Build params struct for router
            IMangoStructs.cParamsRouter memory routerParams = IMangoStructs.cParamsRouter({
                factoryV2: factoryV2,
                factoryV3: factoryV3,
                routerV2: routerV2,
                swapRouter02: swapRouter02,
                weth: weth,
                taxFee: uint16(taxFee),
                referralFee: uint16(referralFee)
            });

            MangoRouter002 mangoRouter = new MangoRouter002(routerParams);
            console.log("Deployed MangoRouter at %s", address(mangoRouter));

            // Only deploy the router on non-base chains. Immediately attempt a small ETH -> USDC
            // swap to validate routing on the fork. If USDC is not configured, skip the swap.
            if (usdc == address(0)) {
                console.log("No USDC configured for %s; skipping swap test.", chainKey);
            } else {
                uint256 testValue = 1e15; // 0.001 ETH
                try mangoRouter.swap{value: testValue}(address(0), usdc, 0, address(0)) returns (uint256 amountOut) {
                    console.log("Swap succeeded on %s: received %s tokens for %s wei", chainKey, amountOut, testValue);
                } catch (bytes memory reason) {
                    if (reason.length > 0) {
                        string memory reasonStr;
                        assembly { reasonStr := add(reason, 0x20) }
                        console.log("Swap reverted on %s with reason (raw): %s", chainKey, reasonStr);
                    } else {
                        console.log("Swap reverted on %s with no reason", chainKey);
                    }
                }
            }

            if (broadcastEnabled) {
                vm.stopBroadcast();
            }

            unchecked { ++i; }
        }

        console.log("\nDone deploying non-base chains.");
    }
}
