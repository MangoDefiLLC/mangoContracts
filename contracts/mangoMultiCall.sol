// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "./interfaces/IERC20.sol";

contract MangoMultiCall {

    struct Call {
        address target;//target address
        uint256 gasLimit;
        bytes callData;//call data of the function to call
    }

    struct Result {
        bool success;
        uint256 gasUsed;
        bytes returnData;
    }

    constructor(){}

    function multicall(Call[] memory calls) public returns (Result[] memory returnData) {

        returnData = new Result[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            
            (address target, uint256 gasLimit, bytes memory callData) =
                (calls[i].target, calls[i].gasLimit, calls[i].callData);
            uint256 gasLeftBefore = gasleft();
            (bool success, bytes memory result) = target.call{gas: gasLimit}(callData);
            uint256 gasUsed = gasLeftBefore - gasleft();
            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            } else {
                returnData[i] = Result(success, gasUsed, result);
            }
        }
    }
    
    
}