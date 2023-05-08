// spdx-License-Identifier: MIT
pragma solidity >=0.5.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract UniswapV3 {
    ISwapRouter private router;
    uint32 private twapPeriod;
    error MinOutError();

    constructor(address _router) {
        router = ISwapRouter(_router);
    }

    function swap(
        address token0,
        address token1,
        uint24 fee,
        uint256 amountIn,
        uint256 minOut
    ) external returns (uint256 amountOut) {
        IERC20(token0).transferFrom(msg.sender, address(this), amountIn);
        IERC20(token0).approve(address(router), amountIn);
        if (
            (amountOut = router.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: token0,
                    tokenOut: token1,
                    fee: fee,
                    recipient: msg.sender,
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: minOut,
                    sqrtPriceLimitX96: 0
                })
            )) < minOut
        ) {
            revert MinOutError();
        }
    }
}
