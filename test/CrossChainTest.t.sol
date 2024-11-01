// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SourceNFT} from "../src/cross-chain-nft/SourceNFT.sol";
import {DestinationNFT} from "../src/cross-chain-nft/DestinationNFT.sol";
import {Gateway} from "@analog-gmp/Gateway.sol";
import {GmpTestTools} from "@analog-gmp-testing/GmpTestTools.sol";
import {GmpMessage, GmpStatus, GmpSender, PrimitiveUtils} from "@analog-gmp/Primitives.sol";

contract CrossChainTest is Test {
    //SourceNFT source;
    //DestinationNFT dest;

    address private OWNER = makeAddr("Owner");
    address private DEVIL = makeAddr("Devil");
    address private USER = makeAddr("User");

    /// @dev Try adding Aleph Zero EVM network
    // Source Network
    Gateway private constant ALEPH_GATEWAY = Gateway(GmpTestTools.SHIBUYA_GATEWAY);
    uint16 private constant ALEPH_NETWORK = GmpTestTools.SHIBUYA_NETWORK_ID;

    // Destination Network
    Gateway private constant ETHEREUM_GATEWAY = Gateway(GmpTestTools.SEPOLIA_GATEWAY);
    uint16 private constant ETHEREUM_NETWORK = GmpTestTools.SEPOLIA_NETWORK_ID;

    function setUp() public {}

    function test_teleportTokens() public {
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
        SourceNFT source = SourceNFT(vm.computeCreateAddress(OWNER, vm.getNonce(OWNER)));
        DestinationNFT dest = DestinationNFT(vm.computeCreateAddress(DEVIL, vm.getNonce(DEVIL)));

        GmpTestTools.switchNetwork(ALEPH_NETWORK, OWNER);
        source = new SourceNFT("Source", "SRC", "http", OWNER, ALEPH_GATEWAY, address(dest), ETHEREUM_NETWORK);

        GmpTestTools.switchNetwork(ETHEREUM_NETWORK, DEVIL);
        dest = new DestinationNFT("Dest", "DST", "https", DEVIL, ETHEREUM_GATEWAY, address(source), ALEPH_NETWORK);

        console.log("Source: ", address(source));
        console.log("Dest: ", address(dest));

        ///////////////////////////////
        // Mint Some Tokens For USER //
        ///////////////////////////////

        GmpTestTools.switchNetwork(ALEPH_NETWORK, OWNER);
        source.safeBatchMint(USER, 10);

        //////////////////////
        // Send GMP message //
        //////////////////////

        uint[] memory tokens = new uint[](3);
        tokens[0] = 1;
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
        bytes32 messageID = source.crossChainTokensTransferFrom{value: fee}(tokens);
    }

    /// @dev Test to be removed as tested functions will be internal
    function test_lockTokens() public {
        // vm.prank(OWNER);
        // source.safeBatchMint(USER, 10);
        // uint[] memory tokens = new uint[](3);
        // tokens[0] = 1;
        // tokens[1] = 5;
        // tokens[2] = 7;
        // assertEq(source.areTokensUnlocked(tokens), true);
        // uint[] memory lockTokens = new uint[](2);
        // lockTokens[0] = 1;
        // lockTokens[1] = 7;
        // source.lockTokens(lockTokens);
        // assertEq(source.areTokensUnlocked(lockTokens), false);
        // assertEq(source.areTokensUnlocked(tokens), false);
        // uint[] memory unlocked = new uint[](1);
        // unlocked[0] = 7;
        // source.unlockTokens(unlocked);
        // assertEq(source.areTokensUnlocked(unlocked), true);
        // assertEq(source.areTokensUnlocked(lockTokens), false);
        // assertEq(source.areTokensUnlocked(tokens), false);
        // vm.expectRevert(SourceNFT.TokensActiveOnOtherChain.selector);
        // source.safeBatchTransferFrom(USER, OWNER, tokens);
        // vm.prank(USER);
        // source.safeBatchTransferFrom(USER, OWNER, unlocked);
    }
}
