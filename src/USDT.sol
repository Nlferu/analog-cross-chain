// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BasicERC20} from "./BasicERC20.sol";
import {GmpSender, PrimitiveUtils} from "@analog-gmp/Primitives.sol";

import {IGateway} from "@analog-gmp/interfaces/IGateway.sol";

/// @dev This needs to be deployed on Sepolia
contract USDT is ERC20 {
    using PrimitiveUtils for GmpSender;

    /// @dev Emitted when `amount` tokens are teleported from one account (`from`) in another chain to an account (`to`) in this chain.
    event InboundTransfer(bytes32 indexed id, address indexed from, address indexed to, uint256 amount);

    IGateway private immutable _trustedGateway;
    BasicERC20 private immutable _recipientErc20;
    uint16 private immutable _recipientNetwork;

    struct TeleportCommand {
        address from;
        address to;
        uint256 amount;
    }

    constructor(IGateway gatewayAddress, BasicERC20 recipient, uint16 recipientNetwork) ERC20("USDT Mock", "USDT", 18) {
        _trustedGateway = gatewayAddress;
        _recipientErc20 = recipient;
        _recipientNetwork = recipientNetwork;

        //_mint(msg.sender, 1000);
    }

    function mint(uint amount) external {
        _mint(msg.sender, amount);
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
