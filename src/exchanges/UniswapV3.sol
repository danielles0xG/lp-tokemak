// spdx-License-Identifier: MIT
pragma solidity >=0.5.0;


import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract UniswapV3 {
    ISwapRouter private router;
    uint32 private twapPeriod;

    constructor(address _router){
        router = ISwapRouter(_router);
    }
    function swap(
        address token0,
        address token1,
        uint256 amountIn
    ) external {
        IERC20(token0).transferFrom(msg.sender,address(this),amountIn);
        IERC20(token0).approve(address(router),amountIn);
        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                    tokenIn:token0,
                    tokenOut:token1,
                    fee:3000,
                    recipient:msg.sender,
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96:0
            }));
    }
}