// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../contracts/TokeLpVault.sol";
import "./mocks/TokePoolMock.sol";
import "./mocks/TokeManagerMock.sol";
import "./mocks/TokeRewardsMock.sol";
import "./mocks/UniRouterV2Mock.sol";
import "../contracts/interfaces/tokemak/IRewards.sol";
import "../contracts/interfaces/tokemak/IManager.sol";
import "../contracts/interfaces/tokemak/ILiquidityPool.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20, MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";



contract TokeLpVaultTest is Test{

    TokeLpVault private vault;

    TokePoolMock private reactor;
    TokeRewardsMock private rewards;
    TokeManagerMock private manager;
    UniRouterV2Mock private swapRouter;
    MockERC20 private lpToken;
    MockERC20 private tokemakToken;


    function setUp() public{
        reactor = new TokePoolMock();
        manager = new TokeManagerMock();
        lpToken = new MockERC20("lpToken", "TLP", 18);
        tokemakToken = new MockERC20("Tokemak","TOKE",18);
        swapRouter = new UniRouterV2Mock(address(lpToken),address(tokemakToken));
        rewards = new TokeRewardsMock(IERC20(address(tokemakToken)),msg.sender);

        vault = new TokeLpVault(
            ILiquidityPool(address(reactor)),
            IRewards(address(rewards)),
            IManager(address(manager)),
            IUniswapV2Router02(address(swapRouter)),
            ERC20(address(lpToken))
        );
    }

    function testReceive() payable external{
        vm.expectRevert();
        address(vault).call{value:1 wei}("");
    }
    function testFallback() external{
        vm.expectRevert();
        address(vault).staticcall(abi.encodeWithSignature("reverts()"));
    }
}