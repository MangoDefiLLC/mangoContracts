pragma solidity ^0.8.20;
interface IManager {
    function burn(uint256 amount) external;
    function withdrawEth(uint256 amount) external;
    function teamFee() view external returns(uint256);
    function buyAndBurnFee() view external returns(uint256);
    function referralFee() view external returns(uint256);
}