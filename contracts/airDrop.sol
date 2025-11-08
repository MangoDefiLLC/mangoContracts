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
        //@DEV AIRDROP TOKENS TO THE LIST
        for(uint256 i = 0; i < holdersList.length;i++){
            //check token balance is bigger or = of amount to distribute
            if(IERC20(token).balanceOf(address(this)) < holdersList[i].balance) revert needMoreBalance();
            // //transfer token to holder
            (bool s,) = token.call(
                abi.encodeWithSignature(
                    'transfer',
                    holdersList[i].userAddress,holdersList[i].balance
                ));
            if(!s) revert TF();
        }
    }

    function withdrawToken(address token,uint256 amount) external{
        if(!whiteList[msg.sender]) revert();
        IERC20(token).transfer(msg.sender,amount);
    }
}