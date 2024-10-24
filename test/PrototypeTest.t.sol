// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Sender} from "../src/Sender.sol";
import {Receiver} from "../src/Receiver.sol";
import {USDT} from "../src/USDT.sol";
import {wUSDT} from "../src/wUSDT.sol";
import {GmpTestTools} from "@analog-gmp-testing/GmpTestTools.sol";
import {Gateway} from "@analog-gmp/Gateway.sol";
import {GmpMessage, GmpStatus, GmpSender, PrimitiveUtils} from "@analog-gmp/Primitives.sol";

contract PrototypeTest is Test {
    using PrimitiveUtils for GmpSender;
    //using PrimitiveUtils for address;

    address private OWNER = makeAddr("Owner");
    address private DEVIL = makeAddr("Devil");
    address private USER = makeAddr("User");

    Gateway private constant SEPOLIA_GATEWAY = Gateway(GmpTestTools.SEPOLIA_GATEWAY);
    uint16 private constant SEPOLIA_NETWORK = GmpTestTools.SEPOLIA_NETWORK_ID;

    Gateway private constant SHIBUYA_GATEWAY = Gateway(GmpTestTools.SHIBUYA_GATEWAY);
    uint16 private constant SHIBUYA_NETWORK = GmpTestTools.SHIBUYA_NETWORK_ID;

    /// @dev Test the teleport of tokens from User's account in Shibuya to Bob's account in Sepolia
    function test_teleport() public {
        console.log("User Address: ", USER);
        console.log("Devil Address: ", DEVIL);

        GmpTestTools.setup();

        console.log("\n  Sepolia Gateway Contract: ", address(SEPOLIA_GATEWAY));
        console.log("Shibuya Gateway Contract: ", address(SHIBUYA_GATEWAY));

        // Add funds to Accounts in all networks
        /// @dev Test if normal .deal on 1 chain only will fail!!!
        GmpTestTools.deal(OWNER, 100 ether);
        GmpTestTools.deal(DEVIL, 100 ether);
        GmpTestTools.deal(USER, 100 ether);

        //////////////////////////////////////////////
        // Deploy the Sender and Receiver contracts //
        //////////////////////////////////////////////

        // Pre-compute the contract addresses, because the contracts must know each other addresses.
        /// @dev Deploying from other addresses to get different contract addresses on both chains
        Sender sender = Sender(vm.computeCreateAddress(OWNER, vm.getNonce(OWNER)));
        Receiver receiver = Receiver(vm.computeCreateAddress(DEVIL, vm.getNonce(DEVIL)));

        // Switch to Shibuya network and deploy the ERC20 using User account
        GmpTestTools.switchNetwork(SEPOLIA_NETWORK, OWNER);
        USDT usdt = new USDT();
        sender = new Sender(SEPOLIA_GATEWAY, receiver, SHIBUYA_NETWORK, address(usdt));

        GmpTestTools.switchNetwork(SHIBUYA_NETWORK, DEVIL);
        wUSDT wusdt = new wUSDT();
        receiver = new Receiver(SHIBUYA_GATEWAY, sender, SEPOLIA_NETWORK, address(wusdt));

        console.log("sender, receiver: ", address(sender), address(receiver));

        // Give user some USDT
        GmpTestTools.switchNetwork(SEPOLIA_NETWORK, USER);
        usdt.mint(1000);

        console.log("\nBalances before bridge...");
        console.log("SEPOLIA NETWORK -> User USDT Balance: ", usdt.balanceOf(USER));
        GmpTestTools.switchNetwork(SHIBUYA_NETWORK, USER);
        console.log("SHIBUYA NETWORK -> User wUSDT Balance: ", wusdt.balanceOf(USER));

        //////////////////////
        // Send GMP message //
        //////////////////////

        // Deposit USDT on Sender contract by triggering teleport fn
        GmpTestTools.switchNetwork(SEPOLIA_NETWORK, USER);
        uint256 fee = sender.teleportCost(SHIBUYA_NETWORK, address(receiver), 200);
        console.log("Fee: ", fee);

        /// @dev User needs to approve Sender contract to deposit USDT on it
        USDT(usdt).approve(address(sender), 200);

        vm.expectEmit(false, true, true, true, address(sender));
        emit Sender.OutboundTransfer(bytes32(0), USER, address(receiver), 200);
        bytes32 messageID = sender.teleport{value: fee}(address(receiver), 200);

        ///////////////////////////////////////////
        // Wait Chronicles Relay the GMP message //
        ///////////////////////////////////////////

        // Now with the `messageID`, User can check the message status in the destination gateway contract
        // status 0: means the message is pending
        // status 1: means the message was executed successfully
        // status 2: means the message was executed but reverted
        GmpTestTools.switchNetwork(SHIBUYA_NETWORK, USER);
        console.log("SHIBUYA NETWORK GMP not executed yet User should have 0 wUSDT balance -> User wUSDT Balance: ", wusdt.balanceOf(USER));
        assertTrue(SHIBUYA_GATEWAY.gmpInfo(messageID).status == GmpStatus.NOT_FOUND, "unexpected message status, expect 'pending'");

        // Note: In a live network, the GMP message will be relayed by Chronicle Nodes after a minimum number of confirmations.
        // here we can simulate this behavior by calling `GmpTestTools.relayMessages()`, this will relay all pending messages.
        //vm.expectEmit(true, true, false, true, address(receiver));
        //emit Receiver.InboundTransfer(messageID, User, address(receiver), 200);
        GmpTestTools.relayMessages();

        // Success! The GMP message was executed!!!
        //assertTrue(SHIBUYA_GATEWAY.gmpInfo(messageID).status == GmpStatus.SUCCESS, "failed to execute GMP");

        GmpTestTools.switchNetwork(SEPOLIA_NETWORK);
        console.log("\nBalances after bridge...");
        console.log("SEPOLIA NETWORK -> User USDT Balance: ", usdt.balanceOf(USER));
        GmpTestTools.switchNetwork(SHIBUYA_NETWORK, USER);
        console.log("SHIBUYA NETWORK -> User wUSDT Balance: ", wusdt.balanceOf(USER));
    }
}
