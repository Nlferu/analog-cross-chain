// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {GmpSender, PrimitiveUtils} from "@analog-gmp/Primitives.sol";

import {IGateway} from "@analog-gmp/interfaces/IGateway.sol";
import {IGmpReceiver} from "@analog-gmp/interfaces/IGmpReceiver.sol";

contract BasicERC20 is ERC20, IGmpReceiver {
    using PrimitiveUtils for GmpSender;

    IGateway private immutable _trustedGateway;
    BasicERC20 private immutable _recipientErc20;
    uint16 private immutable _recipientNetwork;

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

    constructor(
        string memory name,
        string memory symbol,
        IGateway gatewayAddress,
        BasicERC20 recipient,
        uint16 recipientNetwork,
        address holder,
        uint256 initialSupply
    ) ERC20(name, symbol, 10) {
        _trustedGateway = gatewayAddress;
        _recipientErc20 = recipient;
        _recipientNetwork = recipientNetwork;

        if (initialSupply > 0) _mint(holder, initialSupply);
    }

    /// @dev Teleport tokens from `msg.sender` to `recipient` in `_recipientNetwork`
    /// @param recipient The receiver of ERC-20 tokens on the destination chain.
    /// @param amount The amount of ERC-20 tokens the recipient receives.
    function teleport(address recipient, uint256 amount) external payable returns (bytes32 messageID) {
        _burn(msg.sender, amount);

        bytes memory message = abi.encode(TeleportCommand({from: msg.sender, to: recipient, amount: amount}));

        /// @dev Function 'submitMessage()' sends message from chain A to chain B
        /// @param destinationAddress the target address on the destination chain
        /// @param destinationNetwork the target chain where the contract call will be made
        /// @param executionGasLimit the gas limit available for the contract call
        /// @param data message data with no specified format
        messageID = _trustedGateway.submitMessage{value: msg.value}(address(_recipientErc20), _recipientNetwork, MSG_GAS_LIMIT, message);

        emit OutboundTransfer(messageID, msg.sender, recipient, amount);
    }

    function teleportCost(uint16 networkid, address recipient, uint256 amount) public view returns (uint256 deposit) {
        bytes memory message = abi.encode(TeleportCommand({from: msg.sender, to: recipient, amount: amount}));

        return _trustedGateway.estimateMessageCost(networkid, message.length, MSG_GAS_LIMIT);
    }

    function onGmpReceived(bytes32 id, uint128 network, bytes32 sender, bytes calldata data) external payable returns (bytes32) {
        // Convert bytes32 to address
        address senderAddr = GmpSender.wrap(sender).toAddress();

        // Validate the message
        require(msg.sender == address(_trustedGateway), "Unauthorized: only the gateway can call this method");
        require(network == _recipientNetwork, "Unauthorized network");
        require(senderAddr == address(_recipientErc20), "Unauthorized sender");

        // Decode the command
        TeleportCommand memory command = abi.decode(data, (TeleportCommand));

        // Mint the tokens to the destination account
        _mint(command.to, command.amount);

        emit InboundTransfer(id, command.from, command.to, command.amount);

        return id;
    }
}
