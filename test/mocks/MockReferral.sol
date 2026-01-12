// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IMangoReferral} from "../../contracts/interfaces/IMangoReferral.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockReferral is IMangoReferral {
    mapping(address => address) public referralChain;
    bool public shouldRevert = false;

    function getReferralChain(address swapper) external view returns (address) {
        return referralChain[swapper];
    }

    function distributeReferralRewards(
        address swapper,
        uint256 amount,
        address referrer
    ) external returns (bool) {
        if (shouldRevert) return false;
        return true;
    }

    function depositTokens(address token, uint256 amount) external {
        if (shouldRevert) revert("Mock revert");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function addReferralChain(address swapper, address referrer) external returns (bool) {
        referralChain[swapper] = referrer;
        return true;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }
}

