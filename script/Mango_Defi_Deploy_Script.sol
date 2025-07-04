// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import {Script, console} from "forge-std/Script.sol";
// import {MangoRouter002} from "../contracts/mangoRouter001.sol";
// import {MANGO_DEFI} from "../contracts/mangoToken.sol";
// import{IERC20} from '../contracts/interfaces/IERC20.sol';
// import {MangoReferral} from '../contracts/mangoReferral.sol';

// contract Mango_Defi_Deploy_Script is Script {
//     uint256  private privateKey;
//     string  private rpcUrl;
//     MangoRouter002 mangoRouter;
//     MANGO_DEFI mangoToken;
//     MangoReferral mangoReferral;
//     address routerV2 = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3; //sepolia
//     function setUp() public {
//          privateKey = 0x9060a753023c9486b3356bc35c437278358e426c2ba9dd2f4549c6c3b2f4e05e; 
//          rpcUrl = "https://eth-sepolia.g.alchemy.com/v2/9K8pLtRv6cIHwhj_xcoy4rRVX2SFHu3K";
//     }

//     function run() public {
//          // Create a wallet from the private key
//         address deployer = vm.addr(privateKey);
//         console.log(deployer);
//         vm.startBroadcast();

//         mangoRouter = new MangoRouter002();
//         mangoToken = new MANGO_DEFI(routerV2,deployer);
//         mangoReferral = new MangoReferral(deployer,address(mangoRouter),address(mangoToken));
//         console.log('mango router',address(mangoRouter));
//         console.log('mango router',address(mangoToken));
//         console.log('referral',address(mangoReferral));

//     }
// }
