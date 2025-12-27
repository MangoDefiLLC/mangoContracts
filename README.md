## MAngo Defi Contracts
mango defi contracts are the bread and butter of mango echosystem.

##Mango Router##
router is the contract designe to interact with protocols like uniswap, pancake swap and aerodrome and perfomr swaps
Funcitions:
***swap***


*Mango Referral* - the referral contract is desgine to distribute rewards to users when they swap via mango router.( the distribute function can only be called ny a authorize router)
    - *roles*
    - *Owner* can call withdrawal, also call addReferralChain() of a user
    (the add referral chain has to be added to be able to transfer users referreess from another contract)
    - *Manager* is allow to call deposite token function in the referral


*Mango Toke* - ERC20 token wish is the token for the echosystem

*Mango Manager* - the manager is in charge of getting the 3% fee from the router
    - *roles*
    -Owner is able to call the external functions buyback and burs, and distribute
    -router will send the fee amount , hasno other power in the contract or it should
    -Token need to interact with token contract to call burning function
    -Referral the manager should be able to MANGO and fund the referral contract
    **note WARNING** manager should not hold mango tokens
    as function like burn get the amount to burn by calling 
    token.balanceOf(address(manager))
    this takes al mangos tokens in the contract and burns them

## Roles

*Owner* - owner can call specific function on referral contract and router. 
- in Router we have the set referralContract wish allows owner to add a new referral contract, for the router to call the distribution of referral rewrds.
- the owner also has special funcion in referral contract, like setting a router, to allow that router to call the distribute.
- no one else should be able to call this function
*TaxMan* - tax man is a wallet designates to get the fees from router, (this should be a smart contract, also taxman is not owner)
# Actors

**User** - (buyer or seller)| uses mango to swap tokens.

**router** - smart contract to route and execute swaps.

**Manager** - smart contract that will get fees from router and manage them

**Referral** - smart contract to handle referral distribution.
(The distribute and adding referral chain cant only be called by a valid router)

**TaxMan** - tax man is a wallet designates to get the fees from router
                                                         
## Gettin started

Make sure you have forge installed

To get started with this repo
```
    git clone git@github.com:MangoDefiLLC/mangoContracts.git
    forge install
```
## Run Test for router SM
```
forge test -vvv
```


## Mango Depolyment Addresses

| Contract         | Base Address                            | Bsc Address                             |
|------------------|-----------------------------------------|-----------------------------------------|
| MangoRouter002   | 0x157278d12dC2b5bd0cFbF860A64d092d486BfC99 | 0x71978719Fe4103B49bD3d7711eB22421f0410030  |
| MangoReferral    | 0xDBe52cA974cF2593E7E05868dCC15385BD9ef35C | NA                                          |
| MangoToken       | 0x5Ac57Bf5395058893C1a0f4250D301498DCB11fC | NA                                          |
| MangoPresale     | 0x70c39AC1057211F4a4933e01A18e21e06d88E888 | NA                                          |
| MangoAirdrop     | 0x9A80500c425739C4E48f05Bad7f9ddB0CAAe88f0 | NA                                          |

## Mango Router functions
In mango router everything starts with the **swap()** function.

```
    function swap(
        address token0,//tokenIn
        address token1,// tokenOut
        uint256 amount,//amount to swap
        address referrer //referrer address , address(0) if non
        ) external payable returns(uint amountOut)
```
 - ETH-> token swap, token0 needs to be address(0)
 - Token->Eth swap, token1 needs to be address(0)

 we take the same aproach as uniswap, as if token 0 is empty we assume tokenIn is eth and msg.value cannot be 0,
 as you cannot swap eth with out sending a amount
 - for *Token* to *Eth* swap the *msg.value* has to be 0, and amountIn cannot be 0, as if both amount are 0 transaction will revert

#presaleContract
#mangoTokenContracts

#mango router 001
```
0x157278d12dC2b5bd0cFbF860A64d092d486BfC99
Deployer: 0xb4d0bd19178EA860D5AefCdEfEab7fcFE9D8EF17
Deployed to: 0x7cdD5b8C4cA1cCBdC7c7D871046E2a471FA33e90
Transaction hash: 0xcc85fed2bfd132fc7e0b1ad9022ddf02ffab5d71a19e87aa3820c3c8aa733122
```
** MANGO TOKEN CONTRACT**
```
https://repo.sourcify.dev/8453/0x8E161c59F22D41c466aAA7209A16E1Ea2773e383

ADDRESS: 0x8E161c59F22D41c466aAA7209A16E1Ea2773e383 //DEPLOY BY 787 Wllet
```


```

-------  BASE depolyment addresses -------

Mango router:

Deployed to: 0x23F498aB49aA5E24c23d51e225F710E138D0c1D0
Transaction hash: 0x18553dc0238e14407b4c5805de9c8807128c431ca9a1a4ce4c0f3f69b9e5ac27

mangoDefi token:

Deployed to: 0xe3A7bd1f7F0bdEEce9DBb1230E64FFf26cd2C8b6
Transaction hash: 0x5f6b2233cfe46d65877a2af5b0a0ee78fb35887833ab46b10dc5b719e4442c0a


Mango Referral

Deployed to: 0xACAB329d683979C4650A7CfA20d8685Fcd0Cd08F
Transaction hash: 0xb1c367d951c6a66879ee9e43c43139c2ff4ae499224a66ed8880b92c9e06fabe

Presale

Deployed to: 0x979fA80FfccF91f7482Bb7a6Cf821841d193274d
Transaction hash: 0x72c822ee8dfeb511b94958ac1e508e0a5a5112b3d35f05c8028a4d07eaf8edfb

------- sepolia -----------------

ROUTER

Deployer: 0x49f2f071B1Ac90eD1DB1426EA01cA4C145c45d48
Deployed to: 0x9E1672614377bBfdafADD61fB3Aa1897586D0903
Transaction hash: 0x24aff23fca5608aebe1b5f2262629a10f7df58fad1fa8e7bef2bd4fd7fbf368a

MANGO_DEFI



Deployer: 0x49f2f071B1Ac90eD1DB1426EA01cA4C145c45d48
Deployed to: 0xdAbF530587e25f8cB30813CABA0C3CB1DA4f83D4
Transaction hash: 0xef7db78bc67a695d68ec22bc9a81efd720a87cc79837ef8bb8f85e40ea59ad41

MANGO_REFERRAL

Deployer: 0x49f2f071B1Ac90eD1DB1426EA01cA4C145c45d48
Deployed to: 0x7779E7cb3013809D1a8A3Bafee99af09bd6f130c
Transaction hash: 0x7e4a0993d979bbbaf2da81e1bc04ec05cc65dd42d6948f7c8bc01728ad184c43

PRESALE

address :  0x1167606949c9CCF0c66622695Fa0154285bC8B3A
```



exclude this addresses

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



,ock token base add = 0x3534c38E72636ef55E62ed82c7EA0D11B7aF7D23

```
command to deploy mangoContracts % forge script script/DeployScript.s.sol:Deploy_Script --rpc-url $SEPOLIA_RPC --private-key $PVK --broadcast --verify -vvvv
```

# Foundry cool commancs

execute a tx that already happed and se the logs
```
cast run 0xca53b18c543e1a6126574f68f9c4ada58a8c809e7cc453f2c115b1de76f0e528 --rpc-url <YOUR_RPC_URL> [--verbosity <LEVEL>]
```