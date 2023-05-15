//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract LpMock is ERC20 {
    constructor() ERC20("TknMock","TKM", 18) {
    }
    function mint(address to,uint256 amount) public{
        _mint(to,amount);
    }

    function getReserves() public view returns(
        uint112 _reserve0,
        uint112 _reserve1,
        uint32  blockTimestampLast)
    {
            _reserve0 = 5 ether;
            _reserve1 = 5 ether;
            blockTimestampLast = 1;
    }
}
