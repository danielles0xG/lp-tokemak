// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "forge-std/Script.sol";
import {TB} from "../src/test/simulations/TestBase.sol";

import "../src/contracts/interfaces/tokemak/IRewards.sol";
import "../src/contracts/interfaces/tokemak/IManager.sol";
import "../src/contracts/interfaces/tokemak/ILiquidityPool.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../src/contracts/xVault.sol";
import {ERC20} from "@solmate/test/utils/mocks/MockERC20.sol";


contract DeployStrategy is Script {
    uint32 internal constant REWARD_CYCLE = 7 days;
    function run() public {
        vm.startBroadcast();
        address vault = address(new xVault(
            ILiquidityPool(TB.TOKE_SUSHI_REACTOR),
            IRewards(TB.TOKE_REWARDS),
            IManager(TB.TOKE_MANAGER),
            IUniswapV2Router02(TB.SUSHI_ROUTER),
            ERC20(TB.SUSHI_LP_TOKEN),
            REWARD_CYCLE
        ));
        vm.broadcast();
    }
}
