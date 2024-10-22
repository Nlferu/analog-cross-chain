// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@solmate/tokens/ERC20.sol";

/// @dev This needs to be deployed on Sepolia
/// @dev Placeholder token to play real USDT role in the process
contract USDT is ERC20 {
    constructor() ERC20("USDT Mock", "USDT", 18) {}

    function mint(uint amount) external {
        _mint(msg.sender, amount);
    }
}
