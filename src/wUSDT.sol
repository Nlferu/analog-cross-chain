// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@solmate/tokens/ERC20.sol";

/// @dev This contract will wrap USDT to its AZERO version 1:1
/// @dev Owner of this contract needs to be Receiver
contract wUSDT is ERC20 {
    constructor() ERC20("Wrapped USDT", "wUSDT", 18) {}

    function mint(address to, uint amount) external {
        _mint(to, amount);
    }
}
