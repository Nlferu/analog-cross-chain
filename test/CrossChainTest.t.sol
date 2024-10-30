// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SourceNFT} from "../src/cross-chain-nft/SourceNFT.sol";
import {Receiver} from "../src/cross-chain-erc20/Receiver.sol";
import {USDT} from "../src/cross-chain-erc20/USDT.sol";
import {wUSDT} from "../src/cross-chain-erc20/wUSDT.sol";
import {GmpTestTools} from "@analog-gmp-testing/GmpTestTools.sol";
import {Gateway} from "@analog-gmp/Gateway.sol";
import {GmpMessage, GmpStatus, GmpSender, PrimitiveUtils} from "@analog-gmp/Primitives.sol";

contract CrossChainTest is Test {
    SourceNFT source;

    address private OWNER = makeAddr("Owner");
    address private USER = makeAddr("User");

    function setUp() public {
        vm.prank(OWNER);
        source = new SourceNFT("Source", "SRC", "http", OWNER);

        deal(OWNER, 100 ether);
    }

    function test_lockTokens() public {
        vm.prank(OWNER);
        source.safeBatchMint(USER, 10);

        uint[] memory tokens = new uint[](3);
        tokens[0] = 1;
        tokens[1] = 5;
        tokens[2] = 7;

        assertEq(source.areTokensUnlocked(tokens), true);

        uint[] memory lockTokens = new uint[](2);
        lockTokens[0] = 1;
        lockTokens[1] = 7;

        source.lockTokens(lockTokens);

        assertEq(source.areTokensUnlocked(lockTokens), false);
        assertEq(source.areTokensUnlocked(tokens), false);

        uint[] memory unlocked = new uint[](1);
        unlocked[0] = 7;

        source.unlockTokens(unlocked);

        assertEq(source.areTokensUnlocked(unlocked), true);
        assertEq(source.areTokensUnlocked(lockTokens), false);
        assertEq(source.areTokensUnlocked(tokens), false);

        vm.expectRevert(SourceNFT.TokensActiveOnOtherChain.selector);
        source.safeBatchTransferFrom(USER, OWNER, tokens);

        source.safeBatchTransferFrom(USER, OWNER, unlocked);
    }
}
