// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {GmpSender, PrimitiveUtils} from "@analog-gmp/Primitives.sol";

import {IGateway} from "@analog-gmp/interfaces/IGateway.sol";
import {IGmpReceiver} from "@analog-gmp/interfaces/IGmpReceiver.sol";

/// @dev This should be deployed on Shibuya
contract PayableCon {
    error PaymentNotSufficient();

    mapping(address payer => uint funds) public s_balances;

    /// @dev Test User paying USDT to use this function by bridge
    function pay() external payable {
        if (msg.value < 0.02 ether) revert PaymentNotSufficient();

        s_balances[msg.sender] += msg.value;
    }
}
