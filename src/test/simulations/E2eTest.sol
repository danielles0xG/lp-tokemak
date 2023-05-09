// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../../contracts/exchanges/UniswapV3.sol";
import "../../contracts/TokemakStrategy.sol";
import "../../contracts/StrategyRouter.sol";
import "../../contracts/interfaces/tokemak/IRewards.sol";
import "../../contracts/interfaces/tokemak/IManager.sol";
import "../../contracts/interfaces/tokemak/ILiquidityPool.sol";
import "../../contracts/interfaces/IWETH9.sol";
import {TB} from "./TestBase.sol";

/**
    MAINNET FORK INTEGRATION
 */
contract E2eTest is Test {
    UniswapV3 private exchange;
    StrategyRouter private router;
    TokemakStrategy private strategy;
    IERC20 private underlying;
    address private user1;

    function setUp() public {
        // FORK  - Simulate mainnet deployments
        vm.createSelectFork(vm.envString("RPC_MAINNET"), 17110191);
        // Fund user
        user1 = payable(address(uint160(uint256(keccak256(abi.encodePacked("user1"))))));
        vm.label(user1, "user1: ");
        vm.deal(user1, 100 ether);
        vm.startPrank(user1);

        // Deploy contracts
        exchange = new UniswapV3(TB.UNIV3_ROUTER);
        strategy = new TokemakStrategy(
            ILiquidityPool(TB.TOKE_SUSHI_POOL),
            IRewards(TB.TOKE_REWARDS),
            IManager(TB.TOKE_MANAGER),
            IUniswapV2Router02(TB.SUSHI_ROUTER),
            ERC20(TB.SUSHI_LP_TOKEN)
        );
        vm.label(address(strategy), "TokeStrategy");
        router = new StrategyRouter(IWETH9(TB.WETH));
        vm.label(address(router), "StrategyRouter");

        // Label dependency addresses
        vm.label(TB.WETH, "WETH: ");
        vm.label(TB.TOKE, "TOKE: ");
        underlying = IERC20(TB.SUSHI_LP_TOKEN);
        vm.label(address(underlying), "SUSHI_LP_TOKEN");
        vm.label(TB.SUSHI_ROUTER, "SUSHI_ROUTER");
        vm.label(address(this), "THIS");

        uint256 swapAmount = 10 ether;
        IWETH9(TB.WETH).deposit{value: 100 ether}();

        // Buy TOKE on UniswapV3
        IWETH9(TB.WETH).approve(address(exchange), swapAmount);
        uint256 minSwapOut = IQuoter(TB.UNIV3_QUOTER).quoteExactInputSingle(TB.WETH, TB.TOKE, 3000, swapAmount, 0);
        exchange.swap(TB.WETH, TB.TOKE, 3000, swapAmount, minSwapOut);
        uint256 tokeBalance = IERC20(TB.TOKE).balanceOf(user1);
        assert(tokeBalance >= minSwapOut);

        // Provide liquidity to SUHISWAP for toke/weth lp token
        IERC20(TB.WETH).approve(address(TB.SUSHI_ROUTER), type(uint256).max);
        IERC20(TB.TOKE).approve(address(TB.SUSHI_ROUTER), type(uint256).max);

        (uint256 out0, uint256 out1, uint256 lpAmount) = IUniswapV2Router02(TB.SUSHI_ROUTER).addLiquidity(
            TB.WETH,
            TB.TOKE,
            10 ether,
            tokeBalance,
            0,
            0,
            user1,
            block.timestamp
        );
        assert(underlying.balanceOf(user1) >= lpAmount); // eth/toke lp
    }

    function testDepositToVault() public {
        uint256 depositAmount = underlying.balanceOf(user1);
        uint256 minSharesOut = strategy.convertToShares(depositAmount);
        underlying.approve(address(router), depositAmount);
        uint256 sharesOut = router.depositToVault(IERC4626(address(strategy)), user1, minSharesOut, depositAmount);
        assert(sharesOut >= minSharesOut);
    }
}
