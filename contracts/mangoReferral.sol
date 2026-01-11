// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouterV2} from './interfaces/IRouterV2.sol';
import {IMangoStructs} from "./interfaces/IMangoStructs.sol";
import {IMangoErrors} from "./interfaces/IMangoErrors.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
//@DEV
//THIS CONTRACT IS DESIGNE SO DISTRIBUTE THE FEE TO THE REFERRERS
//DISTRIBUTES THE AMOUNTS IN $MANGO
//NOTE: ADD THAT IF OTHER TOKENS IS SENDT IS ABLE TO SWAP IT TO WETH
//@ADD:  RQUIRE MSG.SENDER IS MANGO ROUTER
//NOTE THE AMOUNT THAT IS SENT TO THIS CONTRACT IS ALREADY THE 1% 
//OF THE %3 OF THE SWAP
contract MangoReferral is Ownable{

     address public weth;
     IERC20 public mangoToken;
     IRouterV2 public immutable routerV2;

     mapping(address=>bool) public  whiteListed;//to ensure call is comming from routers
     mapping(address=>uint256) public lifeTimeEarnings;
     mapping(address=>address) public referralChain;// address => referrerAddress
     // Reward percentages for each level (in basis points, 1/100 of a percent)
    // Level 1: 40% (4000 basis points)
    // Level 2: 25% (2500 basis points)
    // Level 3: 15% (1500 basis points)
    // Level 4: 10% (1000 basis points). 
    // Level 5: 10% (1000 basis points)
    uint256[5] public rewardPercentages = [4000, 2500, 1500, 1000, 1000];
   
    event DistributedAmount(uint256 indexed amount);
    event ReferralAdded(address indexed evangelist, address indexed believer);

    struct ReferralReward {
        address referrerAddress;
        uint256 level;
        uint256 amount;
    }
    //pool price from uniswap v2 or v3
    //WARNING MANGO REFERRAL DOESNT GET PRICE FROM POOL

     constructor(IMangoStructs.cReferralParams memory params) Ownable(){//owner is dev wallet 
         require(params.mangoRouter != address(0), "Invalid router");
         require(params.mangoToken != address(0), "Invalid token");
         require(params.routerV2 != address(0), "Invalid routerV2");
         require(params.weth != address(0), "Invalid weth");
         
         //0x49f2f071B1Ac90eD1DB1426EA01cA4C145c45d48;//
         whiteListed[params.mangoRouter] = true;//0x9E1672614377bBfdafADD61fB3Aa1897586D0903
         mangoToken = IERC20(params.mangoToken);//0xdAbF530587e25f8cB30813CABA0C3CB1DA4f83D4
         routerV2 = IRouterV2(params.routerV2);//0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24
         weth =  params.weth;//0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
     }
    function getReferralChain(address swapper) external view returns (address){
        return referralChain[swapper];//returns address(0) when has no referrer
    }
    //CHANGE TO GET PRICE FOM V3 OR V2
    function _getMangoAmountETH(
        uint256 amount
    ) private  returns (uint256 mangoTokensAmount) {
        
            //LOGIC TO GET PRICE FROM UNISWAPV2 POOL
              address[] memory path = new address[](2);
                path[0] = weth;
                path[1] = address(mangoToken);
                
                try routerV2.getAmountsOut(amount, path) returns (uint256[] memory amounts) {
                    mangoTokensAmount = amounts[1];
                } catch {
                    // Fallback: Revert with clear error if pool doesn't exist or oracle fails
                    revert("Price oracle unavailable - MANGO/WETH pool not found");
                }
    }
    /**
     * @notice Distributes referral rewards to the referral chain
     * @dev Converts input amount (ETH) to MANGO tokens using Uniswap price oracle, then distributes
     *      rewards across up to 5 levels of referrers. Only callable by whitelisted routers.
     * @param userAddress Address of the user who initiated the swap
     * @param inputAmount Amount of ETH to distribute (will be converted to MANGO tokens)
     * @param referrer Address of the direct referrer (address(0) if none)
     * @custom:security Only whitelisted routers can call. Prevents duplicate rewards in circular chains.
     */
    function distributeReferralRewards(
        address userAddress,
        uint256 inputAmount,
        address referrer
    ) external payable {
        require(whiteListed[msg.sender],'only mango routers can call Distribution');
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
            emit ReferralAdded(referrer,userAddress);
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

        // Note: Circular referral chains (e.g., A→B→C→A) can exist in the referral system.
        // We prevent duplicate rewards by checking if a referrer has already been processed
        // in this distribution. Each referrer receives a reward only once per distribution,
        // at the first level they appear in the chain, ensuring gas efficiency and fairness.

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

            // Prevent duplicate rewards: Check if this referrer has already been added to rewards
            // This handles circular referral chains (e.g., A→B→C→A where A appears multiple times)
            bool alreadyProcessed = false;
            for (uint8 j = 0; j < chainLength; j++) {
                if (rewards[j].referrerAddress == currentReferrer) {
                    alreadyProcessed = true;
                    break;
                }
            }

            // Skip if this referrer has already been processed in this distribution
            if (alreadyProcessed) {
                // Move to next referrer but don't add duplicate reward
                currentUser = currentReferrer;
                continue;
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
            // Update lifetime earnings for this referrer
            lifeTimeEarnings[reward.referrerAddress] += reward.amount;
        }
        // Emit event once after all transfers complete
        emit DistributedAmount(totalRewardsToDistribute);
        return rewards;
    }
    /**
     * @notice Withdraws ERC20 tokens from the contract to the owner
     * @dev Allows owner to recover tokens sent to the contract
     * @param token Address of the token to withdraw
     * @param amount Amount of tokens to withdraw
     * @custom:security Only owner can call
     */
    function withDrawTokens(address token,uint256 amount) external{
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        require(IERC20(token).transfer(owner(),amount),'transfer failed!');
    }
    /**
     * @notice Withdraws ETH from the contract to the owner
     * @dev Allows owner to recover ETH sent to the contract
     * @param amount Amount of ETH (in wei) to withdraw
     * @custom:security Only owner can call
     */
    function ethWithdraw(uint256 amount) external{
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        (bool s,) = owner().call{value:amount}("");
        require(s);
    }
    /**
     * @notice Updates the MANGO token address used for reward distribution
     * @dev Allows owner to change the token contract if needed
     * @param token Address of the new MANGO token contract
     * @custom:security Only owner can call. Validates zero address.
     */
    function addToken(address token) external {
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        require(token != address(0), "Invalid token address");
        mangoToken = IERC20(token);
    }
    /**
     * @notice Adds a router address to the whitelist for calling distributeReferralRewards
     * @dev Only whitelisted routers can call the distributeReferralRewards function
     * @param router Address of the router to whitelist
     * @custom:security Only owner can call. Validates zero address.
     */
    function addRouter(address router) external {
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        require(router != address(0), "Invalid router address");
        whiteListed[router] = true;

    }
    /**
     * @notice Deposits ERC20 tokens into the referral contract
     * @dev Allows owner to deposit tokens for referral reward distribution
     * @param token Address of the token to deposit
     * @param amount Amount of tokens to deposit
     * @custom:security Only owner can call
     */
    function depositTokens(address token, uint256 amount) public {
        require(msg.sender == owner(),'not allowed to DP');
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }
    //@DEV
    //DEPENDING ON HOW.I GET THE DATA FROM EVENTS
    //MAKE IT A SPECIAL STRUCT TO ALL ALL AT ONCES
    function addReferralChain(address swapper, address referrer)external returns(bool){
        if(msg.sender != owner()) revert IMangoErrors.NotOwner();
        require(swapper != address(0), "Invalid swapper address");
        require(referrer != address(0), "Invalid referrer address");
        require(swapper != referrer, "Cannot refer yourself");
        require(
            referralChain[swapper] == address(0), 
            "Referral chain already exists"
        );
        
        referralChain[swapper] = referrer;
        emit ReferralAdded(referrer, swapper);
        return true;
    }
    /**
     * @notice Revert direct ETH deposits - contract only uses MANGO tokens
     * @dev ETH sent here can only be recovered by owner via ethWithdraw()
     */
    receive() external payable {
        revert("ETH not accepted in referral contract");
    }
}