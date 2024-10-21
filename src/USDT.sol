// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@solmate/tokens/ERC20.sol";

/// @dev This needs to be deployed on Sepolia
contract BasicERC20 is ERC20 {
    constructor() ERC20("USDT Mock", "USDT", 18) {
        _mint(msg.sender, 1000);
    }

    function mint(uint amount) external {
        _mint(msg.sender, amount);
    }
}
