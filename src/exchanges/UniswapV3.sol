// spdx-License-Identifier: MIT
pragma solidity >=0.6.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
// import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
// import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

import "@openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "@openzeppelin-contracts/contracts/access/Ownable.sol";

contract UniswapV3 is Ownable {
    ISwapRouter private router;
    uint32 private twapPeriod;

    constructor(address _router){
        router = ISwapRouter(_router);
    }
    function swap(
        address[] memory path,
        uint256 amountIn
    ) external {
        IERC20(path[0]).transferFrom(msg.sender,address(this),amountIn);
        IERC20(path[0]).approve(address(router),amountIn);
        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                    tokenIn:path[0],
                    tokenOut:path[1],
                    fee:3000,
                    recipient:msg.sender,
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: 0,//_getPrice(path,_toUint128(amountIn)),
                    sqrtPriceLimitX96:0
            }));
    }

    // function updateTwapPeriod(uint32 _newTwapPeriod) external onlyOwner{
    //     twapPeriod = _newTwapPeriod;
    // }

    // ///@notice get TWAP price
    // function _getPrice(address[] memory _assets, uint128 amount) internal returns(uint256){
    //     // address uniswapV3Pool= uniswapFactory.getPool(_assets[0],_assets[1],3000);
    //     (int24 arithmeticMeanTick,) = OracleLibrary.consult(address(0), twapPeriod);
    //     return OracleLibrary.getQuoteAtTick(
    //         arithmeticMeanTick,
    //         amount, // baseAmount
    //         address(_assets[0]), // baseToken
    //         address(_assets[1]) // quoteToken
    //     );
    // }
    
    // function _toUint128(uint256 amount) private pure returns (uint128 n) {
    //     require(amount == (n = uint128(amount)));
    // }
}