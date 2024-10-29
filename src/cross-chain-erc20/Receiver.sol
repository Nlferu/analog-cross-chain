// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {wUSDT} from "./wUSDT.sol";
import {Sender} from "./Sender.sol";

import {IGateway} from "@analog-gmp/interfaces/IGateway.sol";

// This will be our main contract with logic, which has onGMPReceive() with all possible payable functions (buy, buyout, refund etc.) triggers
contract Receiver {
    error PaymentNotSufficient();

    IGateway private immutable _trustedGateway;
    Sender private immutable _sender;
    uint16 private immutable _senderNetwork;
    address private immutable _wUSDT;

    uint pieces;

    mapping(address payer => uint funds) public s_balances;
    mapping(address payer => bool isExternalBuyer) public s_externalBuyers;

    /// @dev Emitted when `amount` tokens are teleported from one account (`from`) in another chain to an account (`to`) in this chain.
    event InboundTransfer(bytes32 indexed id, address indexed from, address indexed to, uint256 amount);

    struct TeleportCommand {
        address from;
        address to;
        uint256 amount;
    }

    constructor(IGateway gatewayAddress, Sender sender, uint16 senderNetwork, address wrapper) {
        _trustedGateway = gatewayAddress;
        _sender = sender;
        _senderNetwork = senderNetwork;
        _wUSDT = wrapper;

        pieces = 1000;
    }

    /// @dev Test User paying USDT to use this function by bridge
    function buy() external payable {
        if (msg.value < 0.02 ether) revert PaymentNotSufficient();

        s_balances[msg.sender] += msg.value;
    }

    function _buy(address from, uint payment, uint boughtAmount) internal {
        pieces - boughtAmount;

        s_balances[from] += payment;
    }

    function onGmpReceived(bytes32 id, uint128 network, bytes32 sender, bytes calldata data) external payable returns (bytes32) {
        // Convert bytes32 to address
        address senderAddr = address(uint160(uint256(sender)));

        // Validate the message
        require(msg.sender == address(_trustedGateway), "Unauthorized: only the gateway can call this method");
        require(network == _senderNetwork, "Unauthorized network");
        require(senderAddr == address(_sender), "Unauthorized sender");

        // Decode the command
        TeleportCommand memory command = abi.decode(data, (TeleportCommand));

        // Mint the tokens to the destination account
        wUSDT(_wUSDT).mint(command.from, command.amount);

        emit InboundTransfer(id, command.from, command.to, command.amount);

        return id;
    }
}
