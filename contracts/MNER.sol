// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {ERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.9/contracts/token/ERC20/ERC20.sol";

contract MNER is ERC20{
  
    constructor(string memory name_, string memory symbol_) ERC20(name_,symbol_) {
        _mint(msg.sender, 2100000000 * 10 ** 18);
    }
    
}
