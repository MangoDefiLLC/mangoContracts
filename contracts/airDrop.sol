pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMangoErrors} from "./interfaces/IMangoErrors.sol";

contract Airdrop{

    struct holder{
        address userAddress;
        uint256 balance;
    }

    error needMoreBalance();
    error TF();

    mapping(address=>bool) public whiteList;

    constructor(){
        whiteList[msg.sender] = true;
    }

    /**
     * @notice Distributes tokens to multiple holders in a single transaction
     * @dev Optimized batch airdrop function. Uses calldata for array parameter to save gas.
     *      Calculates total amount first, then checks balance before distribution to fail fast.
     * @param holdersList Array of holder structs (address + balance)
     * @param token Address of the token to distribute
     * @custom:gas-savings Uses calldata instead of memory for array parameter (saves ~10-20 gas per item)
     * @custom:security Only whitelisted addresses can call. Checks balance before distribution.
     */
    function airDrop(holder[] calldata holdersList,address token) external {
        if(!whiteList[msg.sender]) revert IMangoErrors.NotAuthorized();
        //@DEV AIRDROP TOKENS TO THE LIST
        // Optimized: Cache array length and token contract interface
        uint256 length = holdersList.length;
        IERC20 tokenContract = IERC20(token);
        
        // Calculate total amount needed first
        uint256 totalAmount = 0;
        for(uint256 i = 0; i < length; ) {
            totalAmount += holdersList[i].balance;
            unchecked { ++i; }  // Safe: i < length, will not overflow
        }
        
        // Check balance before starting distribution to fail fast
        if(tokenContract.balanceOf(address(this)) < totalAmount) revert needMoreBalance();
        
        // Distribute tokens to all holders
        for(uint256 i = 0; i < length; ) {
            bool s = tokenContract.transfer(holdersList[i].userAddress, holdersList[i].balance);
            if(!s) revert TF();
            unchecked { ++i; }  // Safe: i < length, will not overflow
        }
    }

    function withdrawToken(address token,uint256 amount) external{
        if(!whiteList[msg.sender]) revert();
        // Optimized: Cache IERC20 interface to avoid repeated creation
        IERC20 tokenContract = IERC20(token);
        tokenContract.transfer(msg.sender,amount);
    }

    function addToWhitelist(address _address) external {
        if(!whiteList[msg.sender]) revert IMangoErrors.NotAuthorized();
        if(_address == address(0)) revert IMangoErrors.ValueIsZero();
        whiteList[_address] = true;
    }

    function removeFromWhitelist(address _address) external {
        if(!whiteList[msg.sender]) revert IMangoErrors.NotAuthorized();
        whiteList[_address] = false;
    }
}