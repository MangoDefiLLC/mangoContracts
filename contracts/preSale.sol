// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Presale is Ownable {
    IERC20 public immutable token;
    IUniswapV2Router02 public uniswapRouter;
    address public immutable weth;

    uint256 public constant TOTAL_PRESALE_TOKENS = 50_000_000_000 * 10**18; // 50B tokens
    uint256 public tokensSold;
    uint256 public constant MAX_ETH = 300 ether;
    uint256 public totalEthRaised;

    uint256 public constant STAGE1_PRICE = 0.00000625 ether; // 50% discount
    uint256 public constant STAGE2_PRICE = 0.000009375 ether; // 25% discount
    uint256 public constant STAGE3_PRICE = 0.0000125 ether; // Launch price

    uint256 public constant STAGE1_LIMIT = 20_000_000_000 * 10**18; // 20B tokens
    uint256 public constant STAGE2_LIMIT = 35_000_000_000 * 10**18; // 35B tokens

    bool public presaleEnded = false;

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event LiquidityAdded(uint256 tokenAmount, uint256 ethAmount);

    constructor(address _token, address _router, address _weth) {
        token = IERC20(_token);
        uniswapRouter = IUniswapV2Router02(_router);
        weth = _weth;
    }

    function buyTokens() external payable {
        require(!presaleEnded, "Presale ended");
        require(msg.value > 0, "Send ETH to buy tokens");
        require(totalEthRaised + msg.value <= MAX_ETH, "Exceeds max ETH limit");

        uint256 tokensToReceive;
        if (tokensSold < STAGE1_LIMIT) {
            tokensToReceive = msg.value / STAGE1_PRICE;
        } else if (tokensSold < STAGE2_LIMIT) {
            tokensToReceive = msg.value / STAGE2_PRICE;
        } else {
            tokensToReceive = msg.value / STAGE3_PRICE;
        }

        require(tokensSold + tokensToReceive <= TOTAL_PRESALE_TOKENS, "Not enough tokens left");

        tokensSold += tokensToReceive;
        totalEthRaised += msg.value;

        require(token.transfer(msg.sender, tokensToReceive), "Token transfer failed");

        emit TokensPurchased(msg.sender, msg.value, tokensToReceive);
    }

    function endPresaleAndAddLiquidity() external onlyOwner {
        require(!presaleEnded, "Presale already ended");

        presaleEnded = true;

        uint256 tokensForLiquidity = 40_000_000_000 * 10**18; // 40B tokens
        uint256 ethForLiquidity = 600_000 ether; // 600k USDC worth in WETH

        token.approve(address(uniswapRouter), tokensForLiquidity);

        uniswapRouter.addLiquidityETH{value: ethForLiquidity}(
            address(token),
            tokensForLiquidity,
            0,
            0,
            owner(),
            block.timestamp + 300
        );

        emit LiquidityAdded(tokensForLiquidity, ethForLiquidity);
    }

    receive() external payable {
        buyTokens();
    }
}
