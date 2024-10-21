// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {GmpSender, PrimitiveUtils} from "@analog-gmp/Primitives.sol";

import {IGateway} from "@analog-gmp/interfaces/IGateway.sol";
import {IGmpReceiver} from "@analog-gmp/interfaces/IGmpReceiver.sol";

/// @dev This should be deployed on Shibuya
abstract contract PayableCon is IGmpReceiver {
    ///////////////////////////////////
    //          Cross-Chain          //
    ///////////////////////////////////

    using PrimitiveUtils for GmpSender;

    /// @dev Emitted when `amount` tokens are teleported from one account (`from`) in this chain to another (`to`) in another chain.
    event OutboundTransfer(bytes32 indexed id, address indexed from, address indexed to, uint256 amount);

    /// @dev Emitted when `amount` tokens are teleported from one account (`from`) in another chain to an account (`to`) in this chain.
    event InboundTransfer(bytes32 indexed id, address indexed from, address indexed to, uint256 amount);

    /// @dev Gas limit used to execute the `onGmpReceived` method.
    uint256 private constant MSG_GAS_LIMIT = 100_000;

    /// @dev Command that will be encoded in the `data` field on the `onGmpReceived` method.
    struct TeleportCommand {
        address from;
        address to;
        uint256 amount;
    }

    IGateway private immutable i_trustedGateway;
    //BasicERC20 private immutable i_recipientErc20;
    uint16 private immutable i_recipientNetwork;

    ///////////////////////////////////

    error PaymentNotSufficient();

    mapping(address payer => uint funds) public s_balances;

    /// @dev Test User paying USDT to use this function by bridge
    function pay() external payable {
        if (msg.value < 0.02 ether) revert PaymentNotSufficient();

        s_balances[msg.sender] += msg.value;
    }
}
