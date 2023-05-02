// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import {WETH} from "@solmate/tokens/WETH.sol";
import "../contracts/interfaces/IWETH9.sol";
import {ERC20, MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {MockERC4626} from "@solmate/test/utils/mocks/MockERC4626.sol";

import "../contracts/interfaces/IWETH9.sol";
import "../contracts/StrategyRouter.sol";

contract StrategyRouterTest is Test {
    StrategyRouter public router;
    function setUp() public{
        router = new StrategyRouter(
            IWETH9(address(new WETH()))
        );
    }

}