// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IMangoStructs{ 
    struct cParamsRouter {
        address factoryV2;
        address factoryV3;
        address routerV2;
        address swapRouter02;
        address weth;
        uint256 taxFee;
        uint256 referralFee;
    }
    struct cReferralParams {
        address mangoRouter;
        address mangoToken;
        address routerV2;
        address weth;
    }

    struct cManagerParams{
        address mangoRouter;
        address mangoReferral;
        address token;
    }
    struct cTokenParams{
        address manager;
        address uniswapRouterV2;//where im getting mango price
        address uniswapRouterV3;
        address uniswapV3Factory;
    }

}