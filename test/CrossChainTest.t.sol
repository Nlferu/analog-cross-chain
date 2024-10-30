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

    function setUp() public {
        source = new SourceNFT("Source", "SRC", "http", OWNER);

        deal(OWNER, 100 ether);
    }

    function test_deploy() public {
        new SourceNFT("Source", "SRC", "http", OWNER);
    }

    function test_lockTokens() public {
        uint[] memory tokens = new uint[](3);
        tokens[0] = 1;
        tokens[1] = 5;
        tokens[2] = 7;

        assertEq(source.areTokensLocked(tokens), false);

        uint[] memory lockTokens = new uint[](2);
        lockTokens[0] = 1;
        lockTokens[1] = 7;

        source.lockTokens(lockTokens);

        assertEq(source.areTokensLocked(lockTokens), true);
        assertEq(source.areTokensLocked(tokens), false);

        uint[] memory unlocked = new uint[](1);
        unlocked[0] = 7;

        source.unlockTokens(unlocked);

        assertEq(source.areTokensLocked(unlocked), false);
        assertEq(source.areTokensLocked(lockTokens), false);
        assertEq(source.areTokensLocked(tokens), false);
    }
}
