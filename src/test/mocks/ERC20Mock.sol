//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor() ERC20("TknMock","TKM", 18) {
    }
    function mint(address to,uint256 amount) public{
        _mint(to,amount);
    }
}
