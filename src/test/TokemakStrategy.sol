// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../contracts/interfaces/IWETH9.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "../contracts/exchanges/UniswapV3.sol";
import "../contracts/TokemakStrategy.sol";

contract StrategyTest is Test {
    UniswapV3 private exchange;
    TokemakStrategy private strategy;
    address private user1;
    address immutable UNIV3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address immutable SUSHI_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant TOKE = 0x2e9d63788249371f1DFC918a52f8d799F4a38C94;
    address private constant SUSHI_LP_TOKEN = 0xd4e7a6e2D03e4e48DfC27dd3f46DF1c176647E38;
    address private constant TOKE_SUSHI_POOL = 0x8858A739eA1dd3D80FE577EF4e0D03E88561FaA3;
    address private constant TOKE_REWARDS = 0x79dD22579112d8a5F7347c5ED7E609e60da713C5;
    address private constant TOKE_MANAGER = 0xA86e412109f77c45a3BC1c5870b880492Fb86A14;

    function setUp() public {
        // set user funds
        exchange = new UniswapV3(UNIV3_ROUTER);
        user1 = payable(address(uint160(uint256(keccak256(abi.encodePacked("user1"))))));
        vm.label(user1, "user1: ");
        vm.label(WETH, "WETH: ");
        vm.label(TOKE, "TOKE: ");
        vm.label(SUSHI_LP_TOKEN, "SUSHI_LP_TOKEN: ");
        vm.label(SUSHI_ROUTER, "SUSHI_ROUTER: ");
        vm.label(address(this), "StrategyTest:");
        vm.deal(user1, 100 ether);

        vm.startPrank(user1);
        uint256 swapAmount = 10 ether;
        IWETH9(WETH).deposit{value: 100 ether}();
        IWETH9(WETH).approve(address(exchange), swapAmount);
        exchange.swap(WETH, TOKE, swapAmount);

        uint256 tokeBalance = IERC20(TOKE).balanceOf(user1);
        uint256 wethBalance = IWETH9(WETH).balanceOf(user1);
        assert(tokeBalance > 0);
        assert(wethBalance > 50 ether);

        // get SUHI toke/weth lp token
        IERC20(WETH).approve(address(SUSHI_ROUTER), type(uint256).max);
        IERC20(TOKE).approve(address(SUSHI_ROUTER), type(uint256).max);
        (uint256 out0, uint256 out1, uint256 lp) = IUniswapV2Router02(SUSHI_ROUTER).addLiquidity(
            WETH,
            TOKE,
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
        strategy.initialize(TOKE_SUSHI_POOL, TOKE_MANAGER, TOKE_MANAGER, SUSHI_ROUTER, WETH, TOKE);
    }

    function testDeposit() external {
        uint256 depositAmount = IERC20(SUSHI_LP_TOKEN).balanceOf(user1);
        IERC20(SUSHI_LP_TOKEN).approve(address(strategy), depositAmount);
        strategy.deposit(depositAmount);

        vm.warp(block.timestamp + 70 days);

        console.log("Lp -70 days", depositAmount);
        console.log("after 70 days", IERC20(SUSHI_LP_TOKEN).balanceOf(user1));
    }
}
