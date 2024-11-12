// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {SourceNFT} from "../src/cross-chain-nft/SourceNFT.sol";
import {DestinationNFT} from "../src/cross-chain-nft/DestinationNFT.sol";
import {Gateway} from "@analog-gmp/Gateway.sol";
import {GmpTestTools} from "@analog-gmp-testing/GmpTestTools.sol";
import {GmpStatus} from "@analog-gmp/Primitives.sol";

contract CrossChainTest is Test {
    SourceNFT source;
    DestinationNFT dest;

    address private OWNER = makeAddr("Owner");
    address private DEVIL = makeAddr("Devil");
    address private USER = makeAddr("User");

    // Source Network
    Gateway private constant ALEPH_GATEWAY = Gateway(GmpTestTools.SHIBUYA_GATEWAY);
    uint16 private constant ALEPH_NETWORK = GmpTestTools.SHIBUYA_NETWORK_ID;

    // Destination Network
    Gateway private constant ETHEREUM_GATEWAY = Gateway(GmpTestTools.SEPOLIA_GATEWAY);
    uint16 private constant ETHEREUM_NETWORK = GmpTestTools.SEPOLIA_NETWORK_ID;

    function setUp() public {
        GmpTestTools.setup();

        /// @dev Test if normal .deal on 1 chain only will fail!!!
        GmpTestTools.deal(OWNER, 100 ether);
        GmpTestTools.deal(DEVIL, 100 ether);
        GmpTestTools.deal(USER, 100 ether);

        ///////////////////////////////////////////////////////
        // Deploy the SourceNFT and DestinationNFT contracts //
        ///////////////////////////////////////////////////////

        // Pre-compute the contract addresses, because the contracts must know each other addresses.
        /// @dev Deploying from other addresses to get different contract addresses on both chains
        source = SourceNFT(vm.computeCreateAddress(OWNER, vm.getNonce(OWNER)));
        dest = DestinationNFT(vm.computeCreateAddress(DEVIL, vm.getNonce(DEVIL)));

        GmpTestTools.switchNetwork(ALEPH_NETWORK, OWNER);
        source = new SourceNFT("Source", "SRC", "http", OWNER, ALEPH_GATEWAY, address(dest), ETHEREUM_NETWORK);

        GmpTestTools.switchNetwork(ETHEREUM_NETWORK, DEVIL);
        dest = new DestinationNFT("Dest", "DST", "https", DEVIL, ETHEREUM_GATEWAY, address(source), ALEPH_NETWORK);

        console.log("Source: ", address(source));
        console.log("Destination: ", address(dest));
    }

    function test_teleportTokensToDestinationChain() public tokensTeleported {
        /// @dev Check if teleported tokens are locked
        uint[] memory tokens_after = new uint[](3);
        tokens_after[0] = 2; // locked
        tokens_after[1] = 5; // locked
        tokens_after[2] = 9; // unlocked

        GmpTestTools.switchNetwork(ALEPH_NETWORK, USER);
        vm.expectRevert(SourceNFT.TokensActiveOnOtherChain.selector);
        source.safeBatchTransferFrom(USER, DEVIL, tokens_after);

        GmpTestTools.switchNetwork(ETHEREUM_NETWORK, USER);
        dest.tokensOfOwnerIn(USER, 2, 11);

        /// @dev TODO:
        // try adding Aleph Zero EVM network to GMP
        // solve double relay overflow error
        // test cross-chain dest tokens ownership transfer
        // test cross-chain reverse from dest to source tokens transfer
        // override all transfer functions on destination chain
        // check source contract functions and seal them

        /// @dev TESTS TODO:
        // approve()
        // delegate()
        // delegateBySig()
        // safeTransferFrom()
        // safeTransferFrom()
        // setApprovalForAll()
        // transferFrom()
    }

    function test_updateOwnershipOfTokensAfterTransferOnDestinationChain() public tokensTeleported {
        /////////////////////////////////
        // Sending Tokens On Alt Chain //
        /////////////////////////////////
        uint[] memory dest_tokens = new uint[](1);
        dest_tokens[0] = 7;

        // Calculating Gateway Fee
        uint alt_fee = dest.transferCost(DEVIL, dest_tokens, false);

        // Batch tokens transfer
        vm.recordLogs();
        vm.expectEmit(false, true, true, true, address(dest));
        emit DestinationNFT.OutboundOwnershipChange(bytes32(0), USER, DEVIL, dest_tokens);
        dest.safeTransferFrom{value: alt_fee}(USER, DEVIL, 7);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        /// @dev Below comes from 'OutboundOwnershipChange'
        /// entries[2].topics[1] comes from 'GmpCreated' emitted from Gateway contract
        bytes32 messageID = entries[3].topics[1];

        assertEq(0x016f7b7d02c9498905cb5dce96c7753ab6b69e9448e1b68ecca28f6d1cd3e911, messageID);

        /// @dev Check if our transfer updated source chain ownership accordingly
        // Now with the `messageID`, we can check the message status in the destination gateway contract
        GmpTestTools.switchNetwork(ALEPH_NETWORK, USER);
        assertTrue(ALEPH_GATEWAY.gmpInfo(messageID).status == GmpStatus.NOT_FOUND, "unexpected message status, expect 'pending'");

        /// @dev TODO
        /// @dev TO BE FIXED AS 'RELAY' CANNOT BE CALLED TWICE
        // Simulate this behavior by calling `GmpTestTools.relayMessages()`, this will relay all pending messages.
        // vm.expectEmit(true, true, true, true, address(source));
        // emit SourceNFT.InboundOwnershipChange(messageID, USER, DEVIL, dest_tokens);
        // GmpTestTools.relayMessages();

        // Check if source tokens are still locked and owned now by proper user
        // Check if tokens are present on destination chain under new user
    }

    function test_updateOwnershipOfTokensAfterBatchTransferOnDestinationChain() public tokensTeleported {
        /////////////////////////////////
        // Sending Tokens On Alt Chain //
        /////////////////////////////////
        uint[] memory dest_tokens = new uint[](2);
        dest_tokens[0] = 2;
        dest_tokens[1] = 7;

        // Calculating Gateway Fee
        uint alt_fee = dest.transferCost(DEVIL, dest_tokens, false);

        // Batch tokens transfer
        vm.expectEmit(false, true, true, true, address(dest));
        emit DestinationNFT.OutboundOwnershipChange(bytes32(0), USER, DEVIL, dest_tokens);
        bytes32 messageID = dest.safeBtachTransfer{value: alt_fee}(DEVIL, dest_tokens);

        /// @dev Check if our transfer updated source chain ownership accordingly
        // Now with the `messageID`, we can check the message status in the destination gateway contract
        GmpTestTools.switchNetwork(ALEPH_NETWORK, USER);
        assertTrue(ALEPH_GATEWAY.gmpInfo(messageID).status == GmpStatus.NOT_FOUND, "unexpected message status, expect 'pending'");

        /// @dev TODO
        /// @dev TO BE FIXED AS 'RELAY' CANNOT BE CALLED TWICE
        // Simulate this behavior by calling `GmpTestTools.relayMessages()`, this will relay all pending messages.
        // vm.expectEmit(true, true, true, true, address(source));
        // emit SourceNFT.InboundOwnershipChange(messageID, USER, DEVIL, dest_tokens);
        // GmpTestTools.relayMessages();

        // Check if source tokens are still locked and owned now by proper user
        // Check if tokens are present on destination chain under new user
    }

    function test_teleportTokensBackward() public tokensTeleported {
        uint[] memory dest_tokens = new uint[](2);
        dest_tokens[0] = 2;
        dest_tokens[1] = 7;

        // Calculating Gateway Fee
        uint alt_fee = dest.transferCost(DEVIL, dest_tokens, true);

        // Batch tokens transfer
        vm.expectEmit(false, true, true, true, address(dest));
        emit DestinationNFT.OutboundTokensTransfer(bytes32(0), USER, address(source), dest_tokens);
        bytes32 messageID = dest.crossChainTokensTransfer{value: alt_fee}(dest_tokens);

        uint[] memory left_tokens = new uint[](1);
        left_tokens[0] = 5;

        assertEq(dest.tokensOfOwnerIn(USER, 2, 11), left_tokens);

        GmpTestTools.switchNetwork(ALEPH_NETWORK, USER);
        assertTrue(ALEPH_GATEWAY.gmpInfo(messageID).status == GmpStatus.NOT_FOUND, "unexpected message status, expect 'pending'");

        /// @dev TODO
        // vm.expectEmit(true, true, true, true, address(source));
        // emit SourceNFT.InboundOwnershipChange(messageID, USER, DEVIL, dest_tokens);
        // GmpTestTools.relayMessages();

        // Now source USER should be able to transfer tokens 2, 7 and dest USER should be owner only of token 5
    }

    /// @dev Temporary test -> to be removed
    function test_tmpTokensTeleport() public {
        ///////////////////////////////
        // Mint Some Tokens For USER //
        ///////////////////////////////

        /// @dev Change with 'tokensTeleported' modifier
        GmpTestTools.switchNetwork(ALEPH_NETWORK, OWNER);
        source.safeBatchMint(USER, 10);

        GmpTestTools.switchNetwork(ETHEREUM_NETWORK, USER);
        dest.mint(5);

        ///////////////////////////////////////////
        // Wait Chronicles Relay the GMP message //
        ///////////////////////////////////////////

        dest.tokensOfOwnerIn(USER, 2, 11);

        /////////////////////////////////
        // Sending Tokens On Alt Chain //
        /////////////////////////////////

        uint[] memory dest_tokens = new uint[](1);
        dest_tokens[0] = 5;

        // Calculating Gateway Fee
        uint alt_fee = dest.transferCost(DEVIL, dest_tokens, false);

        // Batch tokens transfer
        vm.expectEmit(false, true, true, true, address(dest));
        emit DestinationNFT.OutboundOwnershipChange(bytes32(0), USER, DEVIL, dest_tokens);
        bytes32 newMsgID = dest.safeBtachTransfer{value: alt_fee}(DEVIL, dest_tokens);

        /// @dev We need to get mmessageID somehow here
        // Standard token transfer
        // dest.safeTransferFrom{value: alt_fee}(USER, DEVIL, 7);

        /// @dev Check if our transfer updated source chain ownership accordingly
        // Now with the `messageID`, we can check the message status in the destination gateway contract
        GmpTestTools.switchNetwork(ALEPH_NETWORK, USER);
        assertTrue(ALEPH_GATEWAY.gmpInfo(newMsgID).status == GmpStatus.NOT_FOUND, "unexpected message status, expect 'pending'");

        // Simulate this behavior by calling `GmpTestTools.relayMessages()`, this will relay all pending messages.
        vm.expectEmit(true, true, true, true, address(source));
        emit SourceNFT.InboundOwnershipChange(newMsgID, USER, DEVIL, dest_tokens);
        GmpTestTools.relayMessages();

        assertEq(source.ownerOf(5), DEVIL);

        // test cross-chain dest tokens ownership transfer
        // test cross-chain reverse from dest to source tokens transfer

        /// @dev TESTS TODO:
        // approve()
        // delegate()
        // delegateBySig()
        // safeTransferFrom()
        // safeTransferFrom()
        // setApprovalForAll()
        // transferFrom()
    }

    modifier tokensTeleported() {
        ///////////////////////////////
        // Mint Some Tokens For USER //
        ///////////////////////////////
        GmpTestTools.switchNetwork(ALEPH_NETWORK, OWNER);
        source.safeBatchMint(USER, 10);

        //////////////////////
        // Send GMP message //
        //////////////////////

        uint[] memory tokens = new uint[](3);
        tokens[0] = 2;
        tokens[1] = 5;
        tokens[2] = 7;

        // Calculating Gateway Fee
        uint fee = source.transferCost(tokens);

        // Switch Caller From OWNER To USER
        vm.stopPrank();
        vm.prank(USER);
        // We do 'false' here as we do not know messageID
        vm.expectEmit(false, true, true, true, address(source));
        emit SourceNFT.OutboundTokensTransfer(bytes32(0), USER, address(dest), tokens);
        bytes32 messageID = source.crossChainTokensTransfer{value: fee}(tokens);

        ///////////////////////////////////////////
        // Wait Chronicles Relay the GMP message //
        ///////////////////////////////////////////

        // Now with the `messageID`, we can check the message status in the destination gateway contract
        // status 0: means the message is pending
        // status 1: means the message was executed successfully
        // status 2: means the message was executed but reverted
        GmpTestTools.switchNetwork(ETHEREUM_NETWORK, USER);
        console.log("ETHEREUM NETWORK GMP not executed yet, tokens transferred: ", dest.balanceOf(USER));
        assertTrue(ETHEREUM_GATEWAY.gmpInfo(messageID).status == GmpStatus.NOT_FOUND, "unexpected message status, expect 'pending'");

        // Note: In a live network, the GMP message will be relayed by Chronicle Nodes after a minimum number of confirmations.
        // here we can simulate this behavior by calling `GmpTestTools.relayMessages()`, this will relay all pending messages.
        vm.expectEmit(true, true, true, true, address(dest));
        emit DestinationNFT.InboundTokensTransfer(messageID, USER, tokens);
        GmpTestTools.relayMessages();

        _;
    }
}
