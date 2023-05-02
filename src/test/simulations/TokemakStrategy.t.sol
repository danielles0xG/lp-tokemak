// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../../contracts/interfaces/IWETH9.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "../../contracts/exchanges/UniswapV3.sol";
import {TB} from "./TestBase.sol";
import "../../contracts/TokemakStrategy.sol";

contract StrategyTest is Test {
    UniswapV3 private exchange;
    TokemakStrategy private strategy;
    address private user1;

    function setUp() public {
        // set user funds
        exchange = new UniswapV3(TB.UNIV3_ROUTER);
        user1 = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("user1")))))
        );
        vm.label(user1, "user1: ");
        vm.label(TB.WETH, "WETH: ");
        vm.label(TB.TOKE, "TOKE: ");
        vm.label(TB.SUSHI_LP_TOKEN, "SUSHI_LP_TOKEN: ");
        vm.label(TB.SUSHI_ROUTER,"SUSHI_ROUTER: ");
        vm.label(address(this),"StrategyTest:");
        vm.deal(user1, 100 ether);
        

        vm.startPrank(user1);
        uint256 swapAmount = 10 ether;
        IWETH9(TB.WETH).deposit{value: 100 ether}();
        IWETH9(TB.WETH).approve(address(exchange), swapAmount);
        exchange.swap(TB.WETH, TB.TOKE, swapAmount);

        uint256 tokeBalance = IERC20( TB.TOKE).balanceOf(user1);
        uint256 wethBalance =  IWETH9(TB.WETH).balanceOf(user1);
        assert(tokeBalance > 0);
        assert(wethBalance > 50 ether);

        // get SUHI toke/weth lp token
        IERC20(TB.WETH).approve(address(TB.SUSHI_ROUTER), type(uint256).max);
        IERC20(TB.TOKE).approve(address(TB.SUSHI_ROUTER), type(uint256).max);
        (uint256 out0, uint256 out1, uint256 lp) = IUniswapV2Router02(
            TB.SUSHI_ROUTER
        ).addLiquidity(
                TB.WETH,
                TB.TOKE,
                10 ether,
                tokeBalance,
                0,
                0,
                user1,
                block.timestamp
            );
        assert(lp > 0);

        // Deploy Strategy
        strategy = new TokemakStrategy();
        strategy.initialize(
            TB.TOKE_SUSHI_POOL,
            TB.TOKE_MANAGER,
            TB.TOKE_MANAGER,
            TB.SUSHI_ROUTER,
            TB.WETH,
            TB.TOKE
        );
    }

    function testDeposit() external {
         uint256 depositAmount = IERC20(TB.SUSHI_LP_TOKEN).balanceOf(user1);
         IERC20(TB.SUSHI_LP_TOKEN).approve(address(strategy), depositAmount);
         strategy.deposit(depositAmount);

         vm.warp(block.timestamp + 70 days );

         console.log("Lp -70 days",depositAmount);
         console.log("after 70 days",IERC20(TB.SUSHI_LP_TOKEN).balanceOf(user1));

    }
}
