/// contracts/GLDToken.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
//60000000000000000000000000000 60b
import {IERC20} from "./interfaces/IERC20.sol";
import {IMangoReferral} from './interfaces/IMangoReferral.sol';
import {IMangoErrors} from './interfaces/IMangoErrors.sol';

contract Presale {
    address public immutable owner;
    address public immutable mango;
    IMangoReferral public mangoReferral;

    IERC20 public immutable weth;

    bool public presaleEnded;
    uint256 public tokensSold; // Track how many tokens are sold
    uint256 public totalEthRaised;

   // Corrected prices in wei (1 ETH = $1800)
    uint256 public PRICE = 100_000_000_000 wei; // $0.00002 (7e9 wei)

    event TokensPurchased(address indexed buyer, uint256 indexed ethAmount, uint256 indexed tokenAmount);
    event EthWithdrawn(address indexed caller, uint256 indexed amount);
    event Deposit(address indexed sender, uint256 indexed amount);
    event PriceSet(uint256 indexed price);
    event ReferralPayout(uint256 indexed amount);

    constructor(
        address _mango,
        address _weth,
        address _mangoReferral
    ) {
        if(_mango == address(0)) revert IMangoErrors.InvalidAddress();
        if(_weth == address(0)) revert IMangoErrors.InvalidAddress();
        if(_mangoReferral == address(0)) revert IMangoErrors.InvalidAddress();
        
        owner = msg.sender;
        mango = _mango;
        weth = IERC20(_weth);
        mangoReferral = IMangoReferral(_mangoReferral);
        presaleEnded = false;
    }
    
    function depositTokens(address token, uint256 amount) external {
        require(msg.sender == owner, 'Not owner');
        // Optimized: Cache IERC20 interface to avoid repeated creation
        IERC20 tokenContract = IERC20(token);
        bool txS = tokenContract.transferFrom(msg.sender, address(this), amount);
        require(txS, 'Transfer failed');
    }
     function _tax(uint256 _amount) private pure returns(uint256 taxAmount){
        taxAmount = _amount * 300 / 10000;//amount is the amount to user de rest is the fee
    }
     function _referalFee(uint256 amount) private pure returns (uint256 referalPay){//this amount is the 3% for taxMan
        referalPay = amount * 100 / 10000; 
    }
    /**
     * @notice Allows users to purchase MANGO tokens with ETH during the presale
     * @dev Calculates token amount based on current price, handles referral rewards, and enforces max buy limit
     * @param _referrer Address of the referrer (address(0) to check referral contract for existing referrer)
     * @custom:security Requires presale to be active. Max buy limit of 5 ETH. Applies 3% tax and 1% referral fee.
     */
    function buyTokens(address _referrer) public payable {
        if(presaleEnded) revert IMangoErrors.PresaleEnded();
        if(msg.value == 0) revert IMangoErrors.InvalidAmount();
        if(msg.value >= 5e18) revert IMangoErrors.AmountExceedsMaxBuy();

        //IF REFERRER IS NOS PASS STILL CHECK THE REFERRAL CONTRACT
        //TO SEE IF MSG.SENDER IS REFFEREE
        address referrer =  _referrer == address(0) ? mangoReferral.getReferralChain(msg.sender) : _referrer;
        
        unchecked {
            // Safe: totalEthRaised is uint256, msg.value is bounded by block gas limit
            // In practice, msg.value will never overflow uint256 (max uint256 is astronomical)
            totalEthRaised += msg.value;
        }
        uint256 tokensToReceive = getAmountOutETH(msg.value);
        unchecked {
            // Safe: tokensSold is uint256, tokensToReceive is calculated from msg.value
            // tokensToReceive is bounded by msg.value and price, cannot overflow uint256
            tokensSold += tokensToReceive;
        }
        
        // Optimized: Cache IERC20 interface to avoid repeated creation
        IERC20 mangoToken = IERC20(mango);
        if(!mangoToken.transfer(msg.sender, tokensToReceive)) revert IMangoErrors.TransferFailed();
        emit TokensPurchased(msg.sender, msg.value, tokensToReceive);

        //handle referral pay out
        if(referrer > address(0)){
            uint256 taxAmount = _tax(msg.value);
            uint256 referralFeeAmount =  _referalFee(taxAmount);
            mangoReferral.distributeReferralRewards(msg.sender,referralFeeAmount,referrer);
            emit ReferralPayout(referralFeeAmount);
        }
    }
    /**
     * @notice Calculates the amount of MANGO tokens a user will receive for a given ETH amount
     * @dev Uses the current presale price to calculate token amount. Multiplies before dividing for precision.
     * @param amount Amount of ETH (in wei) to calculate tokens for
     * @return tokensToReceive Amount of MANGO tokens that will be received
     */
    function getAmountOutETH(uint256 amount) public view returns (uint256 tokensToReceive) {
            //if fund is less than 135 eth price1
            if(PRICE == 0) revert IMangoErrors.PriceNotSet();
            // Multiply first then divide for better precision
            tokensToReceive = (amount * 10**18) / PRICE;
    }
    function withdrawETH() external returns (uint256 balance) {
        if(msg.sender != owner) revert IMangoErrors.NotOwner();
        balance = address(this).balance;
        (bool success, ) = owner.call{value: balance}("");
        if(!success) revert IMangoErrors.ETHTransferFailed();
        emit EthWithdrawn(msg.sender, balance);
    }
    function withdrawTokens() external returns (uint256 balance) {
        if(msg.sender != owner) revert IMangoErrors.NotOwner();
        // Optimized: Cache IERC20 interface and owner to avoid repeated calls
        IERC20 mangoToken = IERC20(mango);
        address contractOwner = owner;
        balance = mangoToken.balanceOf(address(this));
        bool s = mangoToken.transfer(contractOwner, balance);
        if(!s) revert IMangoErrors.TransferFailed();
    }
    function endPresale() external returns (bool) {
        if(msg.sender != owner) revert IMangoErrors.NotOwner();
        presaleEnded = true;
        return true;
    }
    function setPrice(uint256 newPrice) external {
        if(msg.sender != owner) revert IMangoErrors.NotOwner();
        if(newPrice == 0) revert IMangoErrors.InvalidPrice();
        PRICE = newPrice;
        emit PriceSet(PRICE);
    }
}
