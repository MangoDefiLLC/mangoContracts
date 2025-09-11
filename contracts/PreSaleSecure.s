// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/security/Pausable.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// /**
//  * @title PreSaleSecure
//  * @dev Secure presale contract with reentrancy protection, proper access controls, and enhanced security features
//  */
// contract PreSaleSecure is ReentrancyGuard, Pausable, Ownable {
//     using SafeMath for uint256;

//     // Constants
//     uint256 private constant BASIS_POINTS = 10000;
//     uint256 private constant MIN_PURCHASE = 0.01 ether;
//     uint256 private constant MAX_PURCHASE = 5 ether;
    
//     // Presale configuration
//     struct PresaleStage {
//         uint256 price;          // Price in wei per token
//         uint256 ethThreshold;   // ETH threshold for this stage
//         uint256 tokensAllocated; // Tokens allocated for this stage
//         uint256 tokensSold;     // Tokens sold in this stage
//         bool active;           // Whether stage is active
//     }
    
//     PresaleStage[] public stages;
//     uint256 public currentStage;
    
//     // Contract state
//     IERC20 public immutable mangoToken;
//     address public immutable treasury;
    
//     uint256 public totalEthRaised;
//     uint256 public totalTokensSold;
//     uint256 public maxFunding;
//     uint256 public presaleStartTime;
//     uint256 public presaleEndTime;
    
//     // VIP system with Merkle proof
//     bytes32 public vipMerkleRoot;
//     mapping(address => uint256) public vipAllocations;
//     mapping(address => bool) public hasClaimedVip;
    
//     // User tracking
//     mapping(address => uint256) public userContributions;
//     mapping(address => uint256) public userTokensPurchased;
//     mapping(address => bool) public hasRefunded;
    
//     // Security features
//     mapping(address => uint256) public lastPurchaseTime;
//     uint256 public purchaseCooldown = 1 minutes;
//     bool public whitelistRequired;
//     mapping(address => bool) public whitelist;
    
//     // Events
//     event PresaleStarted(uint256 startTime, uint256 endTime);
//     event TokensPurchased(
//         address indexed buyer,
//         uint256 ethAmount,
//         uint256 tokenAmount,
//         uint256 stage
//     );
//     event VipClaimed(address indexed user, uint256 amount);
//     event StageAdvanced(uint256 newStage);
//     event PresaleEnded(uint256 totalEthRaised, uint256 totalTokensSold);
//     event Refunded(address indexed user, uint256 amount);
//     event WhitelistUpdated(address indexed user, bool whitelisted);
//     event VipMerkleRootUpdated(bytes32 newRoot);
    
//     // Custom errors
//     error PresaleNotActive();
//     error PresaleEnded();
//     error InsufficientPayment();
//     error ExceedsMaxPurchase();
//     error ExceedsMaxFunding();
//     error PurchaseTooFrequent();
//     error NotWhitelisted();
//     error InvalidProof();
//     error AlreadyClaimed();
//     error NoTokensToRefund();
//     error RefundFailed();
//     error InvalidStageConfig();
//     error StageNotActive();

//     modifier whenPresaleActive() {
//         if (block.timestamp < presaleStartTime || block.timestamp > presaleEndTime) {
//             revert PresaleNotActive();
//         }
//         if (totalEthRaised >= maxFunding) {
//             revert ExceedsMaxFunding();
//         }
//         _;
//     }

//     modifier onlyWhitelisted() {
//         if (whitelistRequired && !whitelist[msg.sender]) {
//             revert NotWhitelisted();
//         }
//         _;
//     }

//     modifier cooldownPassed() {
//         if (block.timestamp < lastPurchaseTime[msg.sender].add(purchaseCooldown)) {
//             revert PurchaseTooFrequent();
//         }
//         _;
//     }

//     constructor(
//         address _mangoToken,
//         address _treasury,
//         uint256 _maxFunding,
//         uint256 _presaleDuration,
//         bytes32 _vipMerkleRoot
//     ) {
//         require(_mangoToken != address(0), "Invalid token address");
//         require(_treasury != address(0), "Invalid treasury address");
//         require(_maxFunding > 0, "Invalid max funding");
        
//         mangoToken = IERC20(_mangoToken);
//         treasury = _treasury;
//         maxFunding = _maxFunding;
//         vipMerkleRoot = _vipMerkleRoot;
//         presaleStartTime = block.timestamp;
//         presaleEndTime = block.timestamp.add(_presaleDuration);
        
//         // Initialize presale stages
//         _initializeStages();
        
//         emit PresaleStarted(presaleStartTime, presaleEndTime);
//     }

//     /**
//      * @dev Initialize presale stages with secure configuration
//      */
//     function _initializeStages() internal {
//         // Stage 1: 0-135 ETH at 100 gwei per token
//         stages.push(PresaleStage({
//             price: 100_000_000_000, // 100 gwei
//             ethThreshold: 135 ether,
//             tokensAllocated: 1_350_000_000 * 10**18, // 1.35B tokens
//             tokensSold: 0,
//             active: true
//         }));
        
//         // Stage 2: 135-337.5 ETH at 150 gwei per token
//         stages.push(PresaleStage({
//             price: 150_000_000_000, // 150 gwei
//             ethThreshold: 337.5 ether,
//             tokensAllocated: 1_350_000_000 * 10**18, // 1.35B tokens
//             tokensSold: 0,
//             active: false
//         }));
//     }

//     /**
//      * @dev Purchase tokens with enhanced security
//      */
//     function purchaseTokens() 
//         external 
//         payable 
//         nonReentrant 
//         whenNotPaused 
//         whenPresaleActive 
//         onlyWhitelisted 
//         cooldownPassed 
//     {
//         if (msg.value < MIN_PURCHASE) {
//             revert InsufficientPayment();
//         }
//         if (msg.value > MAX_PURCHASE) {
//             revert ExceedsMaxPurchase();
//         }
//         if (totalEthRaised.add(msg.value) > maxFunding) {
//             revert ExceedsMaxFunding();
//         }

//         // Update last purchase time
//         lastPurchaseTime[msg.sender] = block.timestamp;
        
//         // Calculate tokens to purchase
//         uint256 tokensToMint = _calculateTokensForEth(msg.value);
//         require(tokensToMint > 0, "No tokens to mint");
        
//         // Update state
//         userContributions[msg.sender] = userContributions[msg.sender].add(msg.value);
//         userTokensPurchased[msg.sender] = userTokensPurchased[msg.sender].add(tokensToMint);
//         totalEthRaised = totalEthRaised.add(msg.value);
//         totalTokensSold = totalTokensSold.add(tokensToMint);
        
//         // Update stage tokens sold
//         stages[currentStage].tokensSold = stages[currentStage].tokensSold.add(tokensToMint);
        
//         // Check if we need to advance to next stage
//         _checkAndAdvanceStage();
        
//         // Transfer tokens to buyer
//         require(mangoToken.transfer(msg.sender, tokensToMint), "Token transfer failed");
        
//         emit TokensPurchased(msg.sender, msg.value, tokensToMint, currentStage);
//     }

//     /**
//      * @dev Calculate tokens for ETH amount with cross-stage support
//      */
//     function _calculateTokensForEth(uint256 ethAmount) internal view returns (uint256) {
//         uint256 remainingEth = ethAmount;
//         uint256 totalTokens = 0;
//         uint256 stageIndex = currentStage;
        
//         while (remainingEth > 0 && stageIndex < stages.length) {
//             PresaleStage memory stage = stages[stageIndex];
//             if (!stage.active && stageIndex != currentStage) {
//                 break;
//             }
            
//             uint256 stageEthCapacity = stage.ethThreshold.sub(
//                 stageIndex == 0 ? 0 : stages[stageIndex - 1].ethThreshold
//             );
//             uint256 stageEthUsed = stage.tokensSold.mul(stage.price).div(10**18);
//             uint256 stageEthRemaining = stageEthCapacity.sub(stageEthUsed);
            
//             if (stageEthRemaining == 0) {
//                 stageIndex++;
//                 continue;
//             }
            
//             uint256 ethForThisStage = remainingEth > stageEthRemaining ? stageEthRemaining : remainingEth;
//             uint256 tokensFromStage = ethForThisStage.mul(10**18).div(stage.price);
            
//             totalTokens = totalTokens.add(tokensFromStage);
//             remainingEth = remainingEth.sub(ethForThisStage);
//             stageIndex++;
//         }
        
//         return totalTokens;
//     }

//     /**
//      * @dev Check and advance to next stage if threshold is met
//      */
//     function _checkAndAdvanceStage() internal {
//         if (currentStage >= stages.length - 1) return;
        
//         uint256 currentStageEthUsed = stages[currentStage].tokensSold.mul(stages[currentStage].price).div(10**18);
//         uint256 stageCapacity = stages[currentStage].ethThreshold.sub(
//             currentStage == 0 ? 0 : stages[currentStage - 1].ethThreshold
//         );
        
//         if (currentStageEthUsed >= stageCapacity) {
//             stages[currentStage].active = false;
//             currentStage++;
//             if (currentStage < stages.length) {
//                 stages[currentStage].active = true;
//                 emit StageAdvanced(currentStage);
//             }
//         }
//     }

//     /**
//      * @dev Claim VIP allocation with Merkle proof
//      */
//     function claimVip(
//         uint256 amount,
//         bytes32[] calldata merkleProof
//     ) external nonReentrant whenNotPaused {
//         if (hasClaimedVip[msg.sender]) {
//             revert AlreadyClaimed();
//         }
        
//         // Verify Merkle proof
//         bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
//         if (!MerkleProof.verify(merkleProof, vipMerkleRoot, leaf)) {
//             revert InvalidProof();
//         }
        
//         hasClaimedVip[msg.sender] = true;
//         vipAllocations[msg.sender] = amount;
        
//         // Transfer VIP tokens
//         require(mangoToken.transfer(msg.sender, amount), "VIP token transfer failed");
        
//         emit VipClaimed(msg.sender, amount);
//     }

//     /**
//      * @dev Emergency refund function (if presale fails)
//      */
//     function refund() external nonReentrant whenPaused {
//         uint256 contribution = userContributions[msg.sender];
//         if (contribution == 0 || hasRefunded[msg.sender]) {
//             revert NoTokensToRefund();
//         }
        
//         hasRefunded[msg.sender] = true;
//         userContributions[msg.sender] = 0;
        
//         // Return tokens to contract (user should approve first)
//         uint256 tokensToReturn = userTokensPurchased[msg.sender];
//         if (tokensToReturn > 0) {
//             require(
//                 mangoToken.transferFrom(msg.sender, address(this), tokensToReturn),
//                 "Token return failed"
//             );
//             userTokensPurchased[msg.sender] = 0;
//         }
        
//         // Refund ETH
//         (bool success, ) = msg.sender.call{value: contribution}("");
//         if (!success) {
//             revert RefundFailed();
//         }
        
//         emit Refunded(msg.sender, contribution);
//     }

//     // ============ ADMIN FUNCTIONS ============

//     /**
//      * @dev Update whitelist status
//      */
//     function setWhitelist(address[] calldata users, bool whitelisted) external onlyOwner {
//         for (uint256 i = 0; i < users.length; i++) {
//             whitelist[users[i]] = whitelisted;
//             emit WhitelistUpdated(users[i], whitelisted);
//         }
//     }

//     /**
//      * @dev Toggle whitelist requirement
//      */
//     function setWhitelistRequired(bool required) external onlyOwner {
//         whitelistRequired = required;
//     }

//     /**
//      * @dev Update VIP Merkle root
//      */
//     function setVipMerkleRoot(bytes32 newRoot) external onlyOwner {
//         vipMerkleRoot = newRoot;
//         emit VipMerkleRootUpdated(newRoot);
//     }

//     /**
//      * @dev Update purchase cooldown
//      */
//     function setPurchaseCooldown(uint256 cooldown) external onlyOwner {
//         require(cooldown <= 1 hours, "Cooldown too long");
//         purchaseCooldown = cooldown;
//     }

//     /**
//      * @dev End presale early
//      */
//     function endPresale() external onlyOwner {
//         presaleEndTime = block.timestamp;
//         emit PresaleEnded(totalEthRaised, totalTokensSold);
//     }

//     /**
//      * @dev Withdraw raised funds
//      */
//     function withdrawFunds() external onlyOwner {
//         require(block.timestamp > presaleEndTime, "Presale not ended");
        
//         uint256 balance = address(this).balance;
//         (bool success, ) = treasury.call{value: balance}("");
//         require(success, "Withdrawal failed");
//     }

//     /**
//      * @dev Withdraw unsold tokens
//      */
//     function withdrawUnsoldTokens() external onlyOwner {
//         require(block.timestamp > presaleEndTime, "Presale not ended");
        
//         uint256 balance = mangoToken.balanceOf(address(this));
//         require(mangoToken.transfer(treasury, balance), "Token withdrawal failed");
//     }

//     /**
//      * @dev Emergency pause
//      */
//     function pause() external onlyOwner {
//         _pause();
//     }

//     /**
//      * @dev Unpause
//      */
//     function unpause() external onlyOwner {
//         _unpause();
//     }

//     // ============ VIEW FUNCTIONS ============

//     /**
//      * @dev Get current stage information
//      */
//     function getCurrentStage() external view returns (
//         uint256 stageIndex,
//         uint256 price,
//         uint256 ethThreshold,
//         uint256 tokensAllocated,
//         uint256 tokensSold,
//         bool active
//     ) {
//         if (currentStage >= stages.length) {
//             return (currentStage, 0, 0, 0, 0, false);
//         }
        
//         PresaleStage memory stage = stages[currentStage];
//         return (
//             currentStage,
//             stage.price,
//             stage.ethThreshold,
//             stage.tokensAllocated,
//             stage.tokensSold,
//             stage.active
//         );
//     }

//     /**
//      * @dev Get tokens for ETH amount (preview)
//      */
//     function getTokensForEth(uint256 ethAmount) external view returns (uint256) {
//         return _calculateTokensForEth(ethAmount);
//     }

//     /**
//      * @dev Get presale status
//      */
//     function getPresaleStatus() external view returns (
//         bool active,
//         uint256 startTime,
//         uint256 endTime,
//         uint256 totalRaised,
//         uint256 maxFunding,
//         uint256 progress // in basis points
//     ) {
//         bool isActive = block.timestamp >= presaleStartTime && 
//                        block.timestamp <= presaleEndTime && 
//                        totalEthRaised < maxFunding;
        
//         uint256 progressBP = totalEthRaised.mul(BASIS_POINTS).div(maxFunding);
        
//         return (
//             isActive,
//             presaleStartTime,
//             presaleEndTime,
//             totalEthRaised,
//             maxFunding,
//             progressBP
//         );
//     }

//     /**
//      * @dev Get user presale information
//      */
//     function getUserInfo(address user) external view returns (
//         uint256 contributions,
//         uint256 tokensPurchased,
//         uint256 vipAllocation,
//         bool hasClaimedVipTokens,
//         bool isWhitelisted,
//         uint256 lastPurchase
//     ) {
//         return (
//             userContributions[user],
//             userTokensPurchased[user],
//             vipAllocations[user],
//             hasClaimedVip[user],
//             whitelist[user],
//             lastPurchaseTime[user]
//         );
//     }

//     /**
//      * @dev Verify VIP eligibility
//      */
//     function verifyVipEligibility(
//         address user,
//         uint256 amount,
//         bytes32[] calldata merkleProof
//     ) external view returns (bool) {
//         if (hasClaimedVip[user]) return false;
        
//         bytes32 leaf = keccak256(abi.encodePacked(user, amount));
//         return MerkleProof.verify(merkleProof, vipMerkleRoot, leaf);
//     }

//     // ============ EMERGENCY FUNCTIONS ============

//     /**
//      * @dev Emergency token recovery
//      */
//     function emergencyTokenRecovery(address token, uint256 amount) external onlyOwner {
//         require(token != address(mangoToken) || block.timestamp > presaleEndTime + 30 days, "Cannot recover presale tokens yet");
//         IERC20(token).transfer(owner(), amount);
//     }

//     /**
//      * @dev Emergency ETH recovery
//      */
//     function emergencyEthRecovery() external onlyOwner {
//         require(paused(), "Must be paused");
//         (bool success, ) = owner().call{value: address(this).balance}("");
//         require(success, "Recovery failed");
//     }

//     // ============ RECEIVE FUNCTION ============

//     /**
//      * @dev Receive function for direct ETH sends (redirects to purchase)
//      */
//     receive() external payable {
//         // Only allow direct purchases if presale is active
//         if (block.timestamp >= presaleStartTime && 
//             block.timestamp <= presaleEndTime && 
//             totalEthRaised < maxFunding) {
//             // This will revert if any security checks fail
//             this.purchaseTokens{value: msg.value}();
//         } else {
//             revert PresaleNotActive();
//         }
//     }
// }