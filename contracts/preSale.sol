/// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
//60000000000000000000000000000 60b
import {IERC20} from "./interfaces/IERC20.sol";
import {IMangoReferral} from './interfaces/IMangoReferral.sol';

contract Presale {
    address public immutable owner;
    address public immutable mango;
    IMangoReferral public mangoReferral;

    IERC20 public immutable weth;
    IERC20 public immutable usdc;

    bool public presaleEnded;
    uint256 public tokensSold; // Track how many tokens are sold
    uint256 public totalEthRaised;

   // Corrected prices in wei (1 ETH = $1800)
    uint256 public PRICE; // $0.00002 (7e9 wei)

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event EthWithdrawn(address caller, uint256 amount);
    event Deposit(address sender, uint256 amount);
    event PriceSet(uint256);
    event ReferralPayout(uint256);

    constructor() {
        owner = msg.sender;
        mango = 0xe3A7bd1f7F0bdEEce9DBb1230E64FFf26cd2C8b6;//MANGO sepolia depoye
        weth = IERC20(0x4200000000000000000000000000000000000006);
        //usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        mangoReferral = IMangoReferral(0xACAB329d683979C4650A7CfA20d8685Fcd0Cd08F);
        presaleEnded = false;
    }
    
    function depositTokens(address token, uint256 amount) external {
        require(msg.sender == owner, 'Not owner');
        bool txS = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(txS, 'Transfer failed');
    }
     function _tax(uint256 _amount) private pure returns(uint256 taxAmount){
        taxAmount = _amount * 300 / 10000;//amount is the amount to user de rest is the fee
    }
     function _referalFee(uint256 amount) private pure returns (uint256 referalPay){//this amount is the 3% for taxMan
        referalPay = amount * 100 / 10000; 
    }
    function buyTokens(address _referrer) public payable {
        require(!presaleEnded, "Presale ended");
        require(msg.value > 0, "Send ETH to buy tokens");
        require(msg.value < 5e18,'amount exeds max buy');

        //IF REFERRER IS NOS PASS STILL CHECK THE REFERRAL CONTRACT
        //TO SEE IF MSG.SENDER IS REFFEREE
        address referrer =  _referrer == address(0) ? mangoReferral.getReferralChain(msg.sender) : _referrer;
        
        totalEthRaised += msg.value;
        uint256 tokensToReceive = getAmountOutETH(msg.value);
        tokensSold += tokensToReceive;
        
        require(IERC20(mango).transfer(msg.sender, tokensToReceive), "Token transfer failed");
        emit TokensPurchased(msg.sender, msg.value, tokensToReceive);

        //handle referral pay out
        if(referrer > address(0)){
            uint256 taxAmount = _tax(msg.value);
            uint256 referralFeeAmount =  _referalFee(taxAmount);
            mangoReferral.distributeReferralRewards(msg.sender,referralFeeAmount,referrer);
            emit ReferralPayout(referralFeeAmount);
        }
    }
    function getAmountOutETH(uint256 amount) public view returns (uint256 tokensToReceive) {
            //if fund is less than 135 eth price1
            tokensToReceive = amount / PRICE  * 10**18;
    }
    function withdrawETH() external returns (uint256 balance) {
        require(msg.sender == owner, 'Not owner');
        balance = address(this).balance;
        (bool success, ) = owner.call{value: balance}("");
        require(success, "ETH transfer failed");
        emit EthWithdrawn(msg.sender, balance);
    }
    function withdrawTokens() external returns (uint256 balance) {
        require(msg.sender == owner, 'Not owner');
        balance = IERC20(mango).balanceOf(address(this));
        bool s = IERC20(mango).transfer(owner, balance);
        require(s, "Token transfer failed");
    }
    function endPresale() external returns (bool) {
        require(msg.sender == owner, 'Not owner');
        presaleEnded = true;
        return true;
    }
    function setPrice(uint256 newPrice) external {
        require(msg.sender == owner);
        PRICE = newPrice;
        emit PriceSet(PRICE);
    }
   // fallback() external payable {}
}