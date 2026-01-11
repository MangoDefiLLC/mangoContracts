pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    function airDrop(holder[] memory holdersList,address token) external {
        require(whiteList[msg.sender], "Not authorized");
        //@DEV AIRDROP TOKENS TO THE LIST
        // Calculate total amount needed first
        uint256 totalAmount = 0;
        for(uint256 i = 0; i < holdersList.length; i++){
            totalAmount += holdersList[i].balance;
        }
        
        // Check balance before starting distribution to fail fast
        require(
            IERC20(token).balanceOf(address(this)) >= totalAmount,
            "Insufficient balance"
        );
        
        // Distribute tokens to all holders
        for(uint256 i = 0; i < holdersList.length;i++){
            bool s = IERC20(token).transfer(holdersList[i].userAddress,holdersList[i].balance);
            if(!s) revert TF();
        }
    }

    function withdrawToken(address token,uint256 amount) external{
        if(!whiteList[msg.sender]) revert();
        IERC20(token).transfer(msg.sender,amount);
    }

    function addToWhitelist(address _address) external {
        require(whiteList[msg.sender], "Not authorized");
        require(_address != address(0), "Invalid address");
        whiteList[_address] = true;
    }

    function removeFromWhitelist(address _address) external {
        require(whiteList[msg.sender], "Not authorized");
        whiteList[_address] = false;
    }
}