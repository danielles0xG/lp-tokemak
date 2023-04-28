// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../src/interfaces/IWETH9.sol";

import "../src/exchanges/UniswapV3.sol";

contract StrategyTest is Test {
    UniswapV3 public exchange;
    address private user1;
    address immutable SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;


    function setUp() public {
        exchange = new UniswapV3(SWAP_ROUTER);
        user1 = payable(address(uint160(uint256(keccak256(abi.encodePacked("user1"))))));
    }

    function testSwap() external{
        vm.label(user1,"user1: ");
        vm.deal(user1, 100 ether);
        vm.startPrank(user1);
        uint256 swapAmount = 10 ether;
        IWETH9(WETH).deposit{value:swapAmount}();
        IWETH9(WETH).approve(address(exchange),swapAmount);
        address[] memory path = new address[](2);
        path[0]= WETH;
        path[1]= DAI;
        exchange.swap(path,swapAmount);
        assert(IERC20(DAI).balanceOf(user1) > 0);
    }

}
