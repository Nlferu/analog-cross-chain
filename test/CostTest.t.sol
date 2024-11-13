// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {SourceNFT} from "../src/cross-chain-nft/SourceNFT.sol";
import {DestinationNFT} from "../src/cross-chain-nft/DestinationNFT.sol";
import {Gateway} from "@analog-gmp/Gateway.sol";
import {GmpTestTools} from "@analog-gmp-testing/GmpTestTools.sol";

contract CrossChainTest is Test {
    SourceNFT source;
    DestinationNFT dest;

    // Source Network
    Gateway private constant ALEPH_GATEWAY = Gateway(GmpTestTools.SHIBUYA_GATEWAY);
    uint16 private constant ALEPH_NETWORK = GmpTestTools.SHIBUYA_NETWORK_ID;

    // Destination Network
    Gateway private constant ETHEREUM_GATEWAY = Gateway(GmpTestTools.SEPOLIA_GATEWAY);
    uint16 private constant ETHEREUM_NETWORK = GmpTestTools.SEPOLIA_NETWORK_ID;

    address private OWNER = makeAddr("Owner");

    function test_deployCost() public {
        new SourceNFT("Source", "SRC", "http", OWNER, ALEPH_GATEWAY, address(dest), ETHEREUM_NETWORK);

        // 3_900_533
        // 3_929_401
    }
}
