// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../../contracts/exchanges/UniswapV3.sol";
import "../../contracts/TokeLpVault.sol";
import "../../contracts/interfaces/tokemak/IRewards.sol";
import "../../contracts/interfaces/tokemak/IManager.sol";
import "../../contracts/interfaces/tokemak/ILiquidityPool.sol";
import "../../contracts/interfaces/IWETH9.sol";
import {TB} from "./TestBase.sol";
interface ITokeLpVault {
    event Deposit(address _investor, uint256 _amount);
    event Stake(address _investor, uint256 _amount);
    event Withdraw(address _investor, uint256 _amount);
    event RequestWithdraw(address _investor, uint256 _amount);
}
/**
    MAINNET FORK INTEGRATION
 */
contract E2eTest is Test ,ITokeLpVault{
    UniswapV3 private exchange;

    TokeLpVault private vault;
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
        vault = new TokeLpVault(
            ILiquidityPool(TB.TOKE_SUSHI_REACTOR),
            IRewards(TB.TOKE_REWARDS),
            IManager(TB.TOKE_MANAGER),
            IUniswapV2Router02(TB.SUSHI_ROUTER),
            ERC20(TB.SUSHI_LP_TOKEN)
        );
        vm.label(address(vault), "Tokevault");

        // Label dependency addresses
        vm.label(TB.WETH, "WETH");
        vm.label(TB.TOKE, "TOKE");
        vm.label(TB.TOKE_SUSHI_REACTOR,"TOKE_SUSHI_REACTOR");
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

    function _setDeposit() internal returns(uint256){
        uint256 depositAmount = underlying.balanceOf(user1);
        depositAmount = depositAmount / 2;

        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount,user1);
        return depositAmount;
    }

    function testDeposit() public {
        uint256 depositAmount = underlying.balanceOf(user1);
        depositAmount = depositAmount / 4;
        uint256 minSharesOut = vault.convertToShares(depositAmount);
        underlying.approve(address(vault), depositAmount);
        uint256 sharesOut = vault.deposit(depositAmount,user1);
        assert(ERC20(vault).balanceOf(user1) >= minSharesOut);
    }

    function testRequestWithdrawal() public {
        uint256 depositAmount = _setDeposit();
        vm.expectEmit(true, true, false, true);
        emit RequestWithdraw(user1,depositAmount);
        vault.requestWithdrawal(depositAmount);
    }
    function testWithdraw() public{
        uint256 depositAmount = _setDeposit();
        vm.expectRevert();
        vault.withdraw(depositAmount,user1,user1);
    }
}
