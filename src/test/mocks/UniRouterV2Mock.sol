//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;
import {ERC20, MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";


contract UniRouterV2Mock{

    MockERC20 private weth;
    address private wantToken;
    address private lpToken;

    constructor(address _lpToken,address _wantToken){
        weth = new MockERC20("weth","WETHM",18);
        wantToken = _wantToken;
        lpToken = _lpToken;
    }
    function WETH() external returns(address){
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
        MockERC20(wantToken).mint(msg.sender,amountOutMin);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amount0,
        uint256 amount1,
        uint256 lpAmountAMin,
        uint256 lpAmountBMin
    ) internal returns (uint256 out0, uint256 out1, uint256 lp) {
        MockERC20(lpToken).mint(msg.sender,(amount0 + amount1) * (10**18) / 2);
    }
}  