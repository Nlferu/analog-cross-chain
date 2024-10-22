// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {USDT} from "./USDT.sol";
import {GmpSender, PrimitiveUtils} from "@analog-gmp/Primitives.sol";

import {IGateway} from "@analog-gmp/interfaces/IGateway.sol";

/// @dev This is deployed on Ethereum and acts like a vault for USDT
contract Sender {
    using PrimitiveUtils for GmpSender;

    error FundsAreFrozen();

    IGateway private immutable _trustedGateway;
    USDT private immutable _recipientErc20;
    uint16 private immutable _recipientNetwork;

    mapping(address payer => uint funds) public s_balances;
    mapping(address payer => bool status) public s_freezes;

    /// @dev Gas limit used to execute the `onGmpReceived` method.
    uint256 private constant MSG_GAS_LIMIT = 100_000;

    /// @dev Command that will be encoded in the `data` field on the `onGmpReceived` method.
    struct TeleportCommand {
        address from;
        address to;
        uint256 amount;
    }

    /// @dev Emitted when `amount` tokens are teleported from one account (`from`) in this chain to another (`to`) in another chain.
    event OutboundTransfer(bytes32 indexed id, address indexed from, address indexed to, uint256 amount);

    constructor(IGateway gatewayAddress, USDT recipient, uint16 recipientNetwork) {
        _trustedGateway = gatewayAddress;
        _recipientErc20 = recipient;
        _recipientNetwork = recipientNetwork;
    }

    /// @dev Teleport tokens from `msg.sender` to `recipient` in `_recipientNetwork`
    /// @param recipient The receiver of ERC-20 tokens on the destination chain.
    /// @param amount The amount of ERC-20 tokens the recipient receives.
    function teleport(address recipient, uint256 amount) external payable returns (bytes32 messageID) {
        /// @dev CHANGE THIS TO FREEZE FUNDS!
        // _burn(msg.sender, amount);

        bytes memory message = abi.encode(TeleportCommand({from: msg.sender, to: recipient, amount: amount}));

        /// @dev Function 'submitMessage()' sends message from chain A to chain B
        /// @param destinationAddress the target address on the destination chain
        /// @param destinationNetwork the target chain where the contract call will be made
        /// @param executionGasLimit the gas limit available for the contract call
        /// @param data message data with no specified format
        messageID = _trustedGateway.submitMessage{value: msg.value}(address(_recipientErc20), _recipientNetwork, MSG_GAS_LIMIT, message);

        emit OutboundTransfer(messageID, msg.sender, recipient, amount);

        // Update Storage
        s_freezes[msg.sender] = true;
        s_balances[msg.sender] += msg.value;
    }

    function teleportCost(uint16 networkid, address recipient, uint256 amount) external view returns (uint256 deposit) {
        bytes memory message = abi.encode(TeleportCommand({from: msg.sender, to: recipient, amount: amount}));

        return _trustedGateway.estimateMessageCost(networkid, message.length, MSG_GAS_LIMIT);
    }

    /// @dev Allows user to get back his USDT
    function withdraw() external view {
        if (s_freezes[msg.sender] == true) revert FundsAreFrozen();
    }
}