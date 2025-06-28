
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from './interfaces/IERC20.sol';
import {IRouterV2} from './interfaces/IRouterV2.sol';
//@DEV
//THIS CONTRACT IS DESIGNE SO DISTRIBUTE THE FEE TO THE REFERRERS
//DISTRIBUTES THE AMOUNTS IN $MANGO
//NOTE: ADD THAT IF OTHER TOKENS IS SENDT IS ABLE TO SWAP IT TO WETH
//@ADD:  RQUIRE MSG.SENDER IS MANGO ROUTER
//NOTE THE AMOUNT THAT IS SENT TO THIS CONTRACT IS ALREADY THE 1% 
//OF THE %3 OF THE SWAP
contract MangoReferral {

     address public owner;
     IERC20 public mangoToken;
     bool public presaleEnded;
     address public weth;
     IRouterV2 public immutable routerV2;
     mapping(address=>bool) public  mangoRouters;//to ensure call is comming from routers
     mapping(address=>uint256) public lifeTimeEarnings;
     mapping(address=>address) public referralChain;// address => referrerAddress
     // Reward percentages for each level (in basis points, 1/100 of a percent)
    // Level 1: 40% (4000 basis points)
    // Level 2: 25% (2500 basis points)
    // Level 3: 15% (1500 basis points)
    // Level 4: 10% (1000 basis points). 
    // Level 5: 10% (1000 basis points)
    uint256[5] public constant rewardPercentages = [4000, 2500, 1500, 1000, 1000];
    uint256 public mangoPrice;

    event DistributedAmount(uint256);

    struct ReferralReward {
        address referrerAddress;
        uint256 level;
        uint256 amount;
    }

     constructor(address _owner,address _mangoRouter, address _mangoToken){//owner is dev wallet
         owner = _owner;
         mangoRouters[_mangoRouter] = true;
         mangoToken = IERC20(_mangoToken);
         mangoPrice = 11_390_000_000 wei;
         routerV2 = IRouterV2(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
         weth = 0x4200000000000000000000000000000000000006;
     }
    function getReferralChain(address swapper) external view returns (address){
        return referralChain[swapper];//returns address(0) when has no referrer
    }
    //THIS PRICE IN DETERMINED IN ETH OR WETH
    // SO THIS CONTRACT WILL RECIVES ETH OR WETH
    //TO GET MORE TOKENS IMPLEMENT SWAPPING TOKENS TO WETH
    //THEN PAYINGOUT 
    function _getMangoAmountETH(
        uint256 amount
    ) private view returns (uint256 mangoTokensAmount) {
        if(presaleEnded == true){
            //LOGIC TO GET PRICE FROM UNISWAPV2 POOL
            //if presale ended
              address[] memory path = new address[](2);
                path[0] = weth;
                path[1] = address(mangoToken);
                uint256[] memory amountOut = routerV2.getAmountsOut(amount,path);
                mangoTokensAmount = amountOut[1];
        }else{
            mangoTokensAmount = (amount * 10**18) / mangoPrice; // Fixed
        }
    }
    ///CREATE FUNCTION TO
    function distributeReferralRewards(
        address userAddress,//msg.sender the one initiated the swap
        uint256 inputAmount,//amount to distribute IF THIS AMOUNT IS NOT 0, SWAP TOKEN TO ETH
        address referrer// the referrer
    ) external payable {
        require(mangoRouters[msg.sender],'only mango routers can call Distribution');
        //address referrer = referralChain[_referrer] ? ;
        uint256 mangoTokensAmount = _getMangoAmountETH(inputAmount);

        _buildReferralChainAndTransferRewards(
            userAddress,
            mangoTokensAmount,//Amount to distribute
            referrer
        );
    }

    function _buildReferralChainAndTransferRewards(
        address userAddress,//the one who initiated the TX
        uint256 mangoTokensAmount,//Amount Of $MANGO TO  DISTRIBUTE
        address referrer
    ) private returns (ReferralReward[] memory) {
        // Update Referrer
        if (
            referralChain[userAddress] == address(0) &&
            referrer != address(0) &&
            referrer != userAddress
        ) {
            referralChain[userAddress] = referrer;
        }
        // Check contract's token balance
        uint256 contractBalance = mangoToken.balanceOf(address(this));
        //add if contract is empty, pull necesarry amount from dev wallet to pay users
        require(
            contractBalance > 0,
            "Insufficient contract mango tokens balance"
        );
        // Create array to track rewards (max 5 levels)
        ReferralReward[] memory rewards = new ReferralReward[](5);
        uint256 totalRewardsToDistribute = 0;
        uint8 chainLength = 0;

        // Current user to check for referrer
        address currentUser = userAddress;

        // Traverse up to 5 levels of referrers
        for (uint8 i = 0; i < 5; i++) {
            // Get the referrer of the current user
            address currentReferrer = referralChain[currentUser];

            // Break if no referrer found
            if (currentReferrer == address(0)) {
                break;
            }

            // Calculate reward for this level (in basis points)
            uint256 rewardForLevel = (mangoTokensAmount *
                rewardPercentages[i]) / 10000;

            // Store reward information
            rewards[chainLength] = ReferralReward({
                referrerAddress: currentReferrer,
                level: i + 1,
                amount: rewardForLevel
            });

            // Add to total rewards
            totalRewardsToDistribute =
                totalRewardsToDistribute +
                rewardForLevel;
                
            chainLength++;

            // Move to the next referrer
            currentUser = currentReferrer;
        }

        // Check if we have enough balance to distribute all rewards
        require(
            contractBalance >= totalRewardsToDistribute,
            "Insufficient mango token balance for all rewards"
        );

        // Distribute rewards
        for (uint8 i = 0; i < chainLength; i++) {
            ReferralReward memory reward = rewards[i];

            // Transfer tokens to the referrer
            require(
                mangoToken.transfer(reward.referrerAddress, reward.amount),
                "Token transfer failed"
            );
            emit DistributedAmount(totalRewardsToDistribute);
        }
        return rewards;
    }
    function withDrawTokens(address token,uint256 amount) external{
        require(msg.sender == owner,'not owner');
        require(IERC20(token).transfer(owner,amount),'transfer failed!');
    }
    function ethWithdraw(uint256 amount) external{
        require(msg.sender == owner);
        (bool s,) = owner.call{value:amount}("");
        require(s);
    }
    function addToken(address token) external {
        require(msg.sender == owner);
        mangoToken = IERC20(token);
    }
    function addRouter(address router) external {
        require(msg.sender == owner);
        mangoRouters[router] = true;

    }
    function depositeTokens(address token, uint256 amount) public {
        require(msg.sender == owner || msg.sender == address(this),'not allowed to DP');
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }
    fallback() external {}
}