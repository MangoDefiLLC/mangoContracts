// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MangoRouter002} from "../contracts/mangoRouter001.sol";
import {MANGO_DEFI_TOKEN} from "../contracts/mangoToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMangoStructs} from "../contracts/interfaces/IMangoStructs.sol";
import {MangoReferral} from '../contracts/mangoReferral.sol';
import {Mango_Manager} from "../contracts/manager.sol";
import {IDexLauncher} from "../contracts/interfaces/IDexLauncher.sol";
import {DexLauncher} from "../contracts/poolLauncher.sol";
interface CheatCodes {
           function prank(address) external;    
 }
 struct poolLauncherParams {
            address uniswapV3Factory;
            address uniswapPositionManager;
            address weth;
            int24 tickLower;
            int24 tickHigher;
            int24 poolTick;
        }
contract Deploy_Script is Script {

    MangoRouter002 public mangoRouter;
    MANGO_DEFI_TOKEN public mangoToken;
    MangoReferral public mangoReferral;
    CheatCodes public cheatCodes;
    Mango_Manager public mangoManager;
    uint256 public pvk = vm.envUint("PVK");
    address public taxMan;
    address public routerV2 = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3; //sepolia
    //                          BASE
    string public BASE;
    string public BSC;
    string public SEPOLIA;
    string public ARBITRUM;
    uint256 public baseFork;
    uint256 public sepoliaFork;
    IMangoStructs.cParamsRouter public params;
    event Where(bool);    

    function setUp()external{
        cheatCodes = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        BASE = vm.envString("BASE_RPC");
        SEPOLIA = vm.envString("SEPOLIA_RPC");
        BSC = vm.envString("BSC_RPC");
        ARBITRUM = vm.envString("ARBITRUM_RPC");
        // baseFork = vm.createFork(BASE);
        // sepoliaFork = vm.createFork(SEPOLIA);
        //testForkIdDiffer();
        //setting all contracts
        //selectFork(SEPOLIA);
     
    }
    function selectFork(string memory _chain)public{
        vm.createSelectFork(_chain);

    }

    function run() public {
        vm.startBroadcast(pvk);
        //deployToken();//deployRouter();
        setVariablesByChain(BASE);
        deployRouter();
        vm.stopBroadcast();
        
    }
    function deployRouter()public {
        mangoRouter = new MangoRouter002(params);
        console.log('Router Address:',address(mangoRouter));

    }

    function deployEchoSystem() public {
 
        mangoRouter = new MangoRouter002(params);
        console.log('Router Address:',address(mangoRouter));

        //prepare token params
        IMangoStructs.cTokenParams memory tokenParams = IMangoStructs.cTokenParams(
            address(0),
            params.routerV2,
            params.swapRouter02,
            params.factoryV3
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
    function deployToken() public {

        IMangoStructs.cTokenParams memory _params = IMangoStructs.cTokenParams(
            address(0),
            params.routerV2,
            params.swapRouter02,
            params.factoryV3
        );
        //deploy token
        mangoToken = new MANGO_DEFI_TOKEN(_params);
        console.log('this is mango token',address(mangoToken));
    }
   
    function setVariablesByChain(string memory _activeFork) public {
        bytes32 activeFork = keccak256(abi.encodePacked(_activeFork));

        //@DEV
        //make a function to compare and not have this many line of the same code snipped
        address weth =  activeFork == keccak256(abi.encodePacked(BASE)) ? 0x4200000000000000000000000000000000000006:
                activeFork == keccak256(abi.encodePacked(ARBITRUM)) ? 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1:
                activeFork == keccak256(abi.encodePacked(BSC)) ?  0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c:
                0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;//assume sepolia
        params =  activeFork == keccak256(abi.encodePacked(BASE)) ? IMangoStructs.cParamsRouter(
        //this is base 
        0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6,//factpryv2
        0x33128a8fC17869897dcE68Ed026d694621f6FDfD,//factpry v3
        0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24,//routerv2
        0x2626664c2603336E57B271c5C0b26F421741e481,//swapRouter02
        weth,//weth
        300,//taxFee
        100//fererralFee
        ): activeFork == keccak256(abi.encodePacked(BSC)) ? IMangoStructs.cParamsRouter(
            0xBCfCcbde45cE874adCB698cC183deBcF17952812,//factpryv2
            0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865,//factpry v3
            0x10ED43C718714eb63d5aA57B78B54704E256024E,//routerv2
            0x1b81D678ffb9C0263b24A97847620C99d213eB14,//swapRouter02
            weth,//weth
            300,//taxFee
            100//fererralFee */
        ): IMangoStructs.cParamsRouter(
        //assume  arbitrum
        address(0),//factpryv2 
        0x1F98431c8aD98523631AE4a59f267346ea31F984,//factpry v3
         address(0),//routerv2
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45,//swapRouter02
        weth,//weth
        300,//taxFee
        100//fererralFee
        );
        
    }
}