//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;
import {ERC20, MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import "forge-std/Test.sol";


contract UniRouterV2Mock{

    MockERC20 private weth;
    address private wantToken;
    address private lpToken;

    constructor(address _lpToken){
        weth = new MockERC20("weth","WETHM",18);
        lpToken = _lpToken;
    }
    function WETH() external view returns(address){
        return address(weth);
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts){
        MockERC20(path[0]).transferFrom(msg.sender,address(this),amountIn);
        MockERC20(lpToken).mint(msg.sender,amountOutMin);
        amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 1 ether;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amount0,
        uint256 amount1,
        uint256 lpAmountAMin,
        uint256 lpAmountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 out0, uint256 out1, uint256 lp) {
        uint256 mintAmount = 1 ether;
        MockERC20(lpToken).mint(msg.sender,mintAmount);
        console.log("after mint;");
        out0 = 0;
        out1 = 0;
        lp = mintAmount;
    }
}  