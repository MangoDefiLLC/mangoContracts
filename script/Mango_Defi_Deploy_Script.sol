// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MangoRouter002} from "../contracts/mangoRouter001.sol";
import {MANGO_DEFI_TOKEN} from "../contracts/mangoToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMangoStructs} from "../contracts/interfaces/IMangoStructs.sol";
import {MangoReferral} from '../contracts/mangoReferral.sol';
import {Mango_Manager} from "../contracts/manager.sol";
interface CheatCodes {
           function prank(address) external;    
 }
contract Mango_Defi_Deploy_Script is Script {

    MangoRouter002 public mangoRouter;
    MANGO_DEFI_TOKEN public mangoToken;
    MangoReferral public mangoReferral;
    CheatCodes public cheatCodes;
     Mango_Manager public mangoManager;
    address public routerV2 = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3; //sepolia


    string public BASE;
    string public SEPOLIA;
    uint256 public baseFork;
    uint256 public sepoliaFork;

    function setUp()external{
        cheatCodes = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        BASE = vm.envString("BASE_RPC");
        SEPOLIA = vm.envString("SEPOLIA_RPC");
        baseFork = vm.createFork(BASE);
        sepoliaFork = vm.createFork(SEPOLIA);
        //testForkIdDiffer();
        //setting all contracts
        selectFork(BASE);
    }
    function selectFork(string memory _chain)public{
        vm.createSelectFork(_chain);

    }

    function run() public {
        
    }
      // demonstrate fork ids are unique
    function testForkIdDiffer() public {
        assert(baseFork == baseFork);
    }

    function deployEchoSystem() public {
        //deploy router
        IMangoStructs.cParamsRouter memory params = IMangoStructs.cParamsRouter(
            //this is base 
            0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6,//factpryv2
            0x33128a8fC17869897dcE68Ed026d694621f6FDfD,//factpry v3
            0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24,//routerv2
            0x2626664c2603336E57B271c5C0b26F421741e481,//swapRouter02
            0x4200000000000000000000000000000000000006,//weth
            300,//taxFee
            100//fererralFee
        );
        /**sepolia
        0xF62c03E08ada871A0bEb309762E260a7a6a880E6,//factpryv2
        0x0227628f3F023bb0B980b67D528571c95c6DaC1c,//factoryV3
        0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3,//routerV2
        0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E//swapRouter02
        300,//taxFee
        100//fererralFee 
        */
        /**
         //this is BSC
            0xBCfCcbde45cE874adCB698cC183deBcF17952812,//factpryv2
            0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865,//factpry v3
            0x10ED43C718714eb63d5aA57B78B54704E256024E,//routerv2
            0x1b81D678ffb9C0263b24A97847620C99d213eB14,//swapRouter02
            0x4200000000000000000000000000000000000006,//weth
            300,//taxFee
            100//fererralFee */


        mangoRouter = new MangoRouter002(params);
        console.log('Router Address:',address(mangoRouter));

        //prepare token params
        IMangoStructs.cTokenParams memory tokenParams = IMangoStructs.cTokenParams(
            address(0),
            address(0),
            address(0),
            address(0)
        );
        //deploy token
        mangoToken = new MANGO_DEFI_TOKEN(tokenParams);
        
        //setting up params for referral
        IMangoStructs.cReferralParams memory referralParams = IMangoStructs.cReferralParams(
            address(mangoRouter),//router address
            address(mangoToken),
            params.routerV2,
            params.weth
        );
        //deploy referral
        mangoReferral = new MangoReferral(referralParams);

        //prapre params for mangoManager
        IMangoStructs.cManagerParams memory mangoManagerParams = IMangoStructs.cManagerParams(
            address(mangoRouter),
            address(mangoReferral),
            address(mangoToken)
        );
        mangoManager = new Mango_Manager(mangoManagerParams);

        //@DEV Now we set all the current contracts

        //set referral contract on router
        mangoRouter.setReferralContract(address(mangoReferral));

        //validate router to call referral
        mangoReferral.addRouter(address(mangoRouter));
        mangoReferral.addToken((address(mangoToken)));

        taxMan = address(mangoManager);
        //add tax man
        mangoRouter.changeTaxMan(taxMan);

        //approve referral for deposite
        mangoToken.approve(address(mangoReferral), type(uint256).max);
        mangoReferral.depositeTokens(address(mangoToken),5000000e18);
    }
}
