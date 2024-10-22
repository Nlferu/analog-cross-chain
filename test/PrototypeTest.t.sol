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
    address private ALICE = makeAddr("Alice");

    Gateway private constant SEPOLIA_GATEWAY = Gateway(GmpTestTools.SEPOLIA_GATEWAY);
    uint16 private constant SEPOLIA_NETWORK = GmpTestTools.SEPOLIA_NETWORK_ID;

    Gateway private constant SHIBUYA_GATEWAY = Gateway(GmpTestTools.SHIBUYA_GATEWAY);
    uint16 private constant SHIBUYA_NETWORK = GmpTestTools.SHIBUYA_NETWORK_ID;

    /// @dev Test the teleport of tokens from Alice's account in Shibuya to Bob's account in Sepolia
    function test_teleport() public {
        console.log("Alice Address: ", ALICE);
        console.log("Devil Address: ", DEVIL);

        GmpTestTools.setup();

        console.log("\n  Sepolia Gateway Contract: ", address(SEPOLIA_GATEWAY));
        console.log("Shibuya Gateway Contract: ", address(SHIBUYA_GATEWAY));

        // Add funds to Accounts in all networks
        /// @dev Test if normal .deal on 1 chain only will fail!!!
        GmpTestTools.deal(OWNER, 100 ether);
        GmpTestTools.deal(DEVIL, 100 ether);
        GmpTestTools.deal(ALICE, 100 ether);

        //////////////////////////////////////////////
        // Deploy the Sender and Receiver contracts //
        //////////////////////////////////////////////

        // Pre-compute the contract addresses, because the contracts must know each other addresses.
        Sender sender = Sender(vm.computeCreateAddress(OWNER, vm.getNonce(OWNER)));
        Receiver receiver = Receiver(vm.computeCreateAddress(DEVIL, vm.getNonce(DEVIL)));

        // Switch to Shibuya network and deploy the ERC20 using Alice account
        GmpTestTools.switchNetwork(SEPOLIA_NETWORK, OWNER);
        USDT usdt = new USDT();
        sender = new Sender(SEPOLIA_GATEWAY, receiver, SHIBUYA_NETWORK, address(usdt));

        GmpTestTools.switchNetwork(SHIBUYA_NETWORK, DEVIL);
        wUSDT wusdt = new wUSDT();
        receiver = new Receiver(SHIBUYA_GATEWAY, sender, SEPOLIA_NETWORK, address(wusdt));

        console.log("sender, receiver: ", address(sender), address(receiver));

        // Give user some USDT
        GmpTestTools.switchNetwork(SEPOLIA_NETWORK, ALICE);
        usdt.mint(1000);

        console.log("\nBalances before bridge...");
        console.log("SEPOLIA NETWORK -> Alice USDT Balance: ", usdt.balanceOf(ALICE));
        GmpTestTools.switchNetwork(SHIBUYA_NETWORK, ALICE);
        console.log("SHIBUYA NETWORK -> Alice wUSDT Balance: ", wusdt.balanceOf(ALICE));

        // Deposit USDT on Sender contract by triggering teleport fn
        GmpTestTools.switchNetwork(SEPOLIA_NETWORK, ALICE);
        USDT(usdt).approve(address(sender), 200);
        sender.transMe(200);
        // uint256 deposit = sender.teleportCost(SHIBUYA_NETWORK, address(receiver), 200);
        // console.log("Deposit: ", deposit);
        // vm.expectEmit(false, true, true, true, address(sender));
        // emit Sender.OutboundTransfer(bytes32(0), ALICE, address(receiver), 200);
        // sender.teleport{value: deposit}(address(receiver), 200);
    }
}
