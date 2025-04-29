/// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
//60000000000000000000000000000 60b
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Presale {
    address public immutable owner;
    address public immutable mango;
    uint256 public immutable maxFunding = 337500000000000000000;


    IERC20 public immutable weth;
    IERC20 public immutable usdc;

    bool public presaleEnded;
    uint256 public tokensSold; // Track how many tokens are sold
    uint256 public FundTarget;
    uint256 public totalEthRaised;
    address[] public vips;
    
   // Corrected prices in wei (1 ETH = $1800)
    uint256 public constant STAGE1_PRICE = 100_000_000_000 wei; // $0.00002 (7e9 wei)
    uint256 public constant STAGE2_PRICE = 150_000_000_000 wei; // $0.00003(9e9 wei)
    uint256 public constant vipAmount0 = 750_000_000 * 10**18; // 750 million
    uint256 public constant vipAmount1 = 375_000_000 * 10**18; // 375 million

    // Adjusted stage limits
    uint256 public constant STAGE1_LIMIT = 13_500_000_000 * 10**18; // 13.5B tokens
    uint256 public constant STAGE2_LIMIT = 13_500_000_000 * 10**18; // 13.5B tokens
    
    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event EthWithdrawn(address caller, uint256 amount);
    event Deposit(address sender, uint256 amount);

    constructor(address _token) {
        owner = msg.sender;
        mango = _token;
        weth = IERC20(0x4200000000000000000000000000000000000006);//0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);//base weth 0x4200000000000000000000000000000000000006
        usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        presaleEnded = false;
        vips = [
            0xdA793BE3CC27daDb2EdbA4DEd7F8d1d97EA26065,
            0xD0D9591BF7abA1ac477eA4fB886975FECb20b267,
            0x567b9f79100Cdc707c2a48F2b844a89CCC13536F,
            0x30a8FA0eB86e1488dED6dAF3f538ECa504aC8196,
            0xE0C17092CFDB7ef6C7442BDd17d912dEFB9fAc1B,
            0xE4F5F4E06aFfd4ED58A0c8049C1B46e4565100E9,
            0x2AfA86FF43815cD38946dFFD122100888a5e3e8A,
            0xcB5E3E04bbD324815AB41Bde672989bc3bE51Ce5,
            0x649935319a41be613994517cB1D131eE819700Ff,
            0x9a1CC60f7bD7d9Fd8a2188c61FAd4fdb85c96989,
            0x970DC297564Fd38bA8d018075e83A835Bc4e4564,
            0xbC5d1d39EBC6B14512D0c3E7710c486226400830,
            0x72DDF303748d0a24A08Eb1666386Abc22b011bb5,
            0x35b8Fd70f290b15EE9948C2e97D39D6A64066485,
            0x3F38422E3f9F51401eCf023053a9d9811ddf1E2E,
            0x244601850c11B6Ce92C4730Bab3B4696417Fe99a,
            0x174D3B496495F05bba764B6b027257DacF425Ec1,
            0xA5A8c3f62B6211e08f4fb93fC8B0C25d75BbCDaC,
            0xe0130b2D7B1b8b861a58c9803692F93432F232cf,
            0x2d6D133844aeA1742595080079A4DbDb79C1ace9,
            0x2cFCAceaBE2e62a4F2eB5b2cebe4801fb8c20303,
            0x89beEA1F4E6807ECb47d486A106F4c2E0BB3E264,
            0x3e3F6D62362f18C6c1b4f25E223ED53eb79dfD40,
            0x125616dB90cf472d08D62C5cE654866766ec3c0B,
            0x5f0Beb6Fb1A2d47f5d1019Ad55DD27928946101a,
            0xC77b2C707B094237643F63B940ef78057f043aDC,
            0x89562BA9beBA1961C5Fa4Ee19106e6EA4FaA24e2,
            0xd249De582410f3462e938fD5aa22eE820e00Ff51,
            0x11c302af6C946C835D3FB235bBb6cc9a62E36dbE,
            0x94d5cf38de8fc83818936d2eD5eeC2D4741394be
        ];
    }
    
    function claimVip() external returns(uint256){
        for (uint256 i = 0; i < vips.length;i++){
            if(i > 10){
                IERC20(mango).transfer(vips[i], vipAmount1);
            }else{
                IERC20(mango).transfer(vips[i], vipAmount0);
            }
        }
        
    }
    function depositTokens(address token, uint256 amount) external {
        require(msg.sender == owner, 'Not owner');
        bool txS = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(txS, 'Transfer failed');
    }
    function buyTokens() public payable {
        require(!presaleEnded, "Presale ended");
        require(msg.value > 0, "Send ETH to buy tokens");
        require(msg.value < 5e18,'amount exeds max buy');

        totalEthRaised += msg.value;
        uint256 tokensToReceive = getAmountOutETH(msg.value);
        tokensSold += tokensToReceive;
        
        require(IERC20(mango).transfer(msg.sender, tokensToReceive), "Token transfer failed");
        emit TokensPurchased(msg.sender, msg.value, tokensToReceive);
    }
    function getAmountOutETH(uint256 amount) public view returns (uint256 tokensToReceive) {
        if (totalEthRaised <= 135000000000000000000) {//if fund is less than 135 eth price1
            tokensToReceive = amount / STAGE1_PRICE  * 10**18;
        } else if (totalEthRaised <= 202500000000000000000) {//202.5
            tokensToReceive = amount / STAGE2_PRICE  * 10**18 ;
        }  else {
            tokensToReceive = 0;
        }
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
   // fallback() external payable {}
}