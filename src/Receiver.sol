// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {wUSDT} from "./wUSDT.sol";
import {Sender} from "./Sender.sol";
import {GmpSender, PrimitiveUtils} from "@analog-gmp/Primitives.sol";

import {IGateway} from "@analog-gmp/interfaces/IGateway.sol";

// This will be our main contract with logic, which has onGMPReceive() with all possible payable functions (buy, buyout, refund etc.) triggers
contract Receiver {
    using PrimitiveUtils for GmpSender;

    /// @dev Emitted when `amount` tokens are teleported from one account (`from`) in another chain to an account (`to`) in this chain.
    event InboundTransfer(bytes32 indexed id, address indexed from, address indexed to, uint256 amount);

    IGateway private immutable _trustedGateway;
    Sender private immutable _sender;
    uint16 private immutable _recipientNetwork;
    address private immutable _wUSDT;

    struct TeleportCommand {
        address from;
        address to;
        uint256 amount;
    }

    constructor(IGateway gatewayAddress, Sender sender, uint16 recipientNetwork, address wrapper) {
        _trustedGateway = gatewayAddress;
        _sender = sender;
        _recipientNetwork = recipientNetwork;
        _wUSDT = wrapper;
    }

    function onGmpReceived(bytes32 id, uint128 network, bytes32 sender, bytes calldata data) external payable returns (bytes32) {
        // Convert bytes32 to address
        address senderAddr = GmpSender.wrap(sender).toAddress();

        // Validate the message
        require(msg.sender == address(_trustedGateway), "Unauthorized: only the gateway can call this method");
        require(network == _recipientNetwork, "Unauthorized network");
        require(senderAddr == address(_sender), "Unauthorized sender");

        // Decode the command
        TeleportCommand memory command = abi.decode(data, (TeleportCommand));

        // Mint the tokens to the destination account
        wUSDT(_wUSDT).mint(command.to, command.amount);

        emit InboundTransfer(id, command.from, command.to, command.amount);

        return id;
    }
}
