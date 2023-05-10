//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "./external/ERC4626RouterBase.sol";
import "./interfaces/IWETH9.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract StrategyRouter is ERC4626RouterBase {

    constructor(IWETH9 _weth) PeripheryPayments(_weth) {
        require(address(_weth) != address(0));
    }
    function depositToVault(
        IERC4626 vault,
        address to,
        uint256 amount,
        uint256 minSharesOut
    ) external payable returns (uint256 sharesOut) {
        pullToken(ERC20(vault.asset()), amount, address(this));
        SafeERC20.safeIncreaseAllowance(IERC20(address(vault.asset())),address(vault), amount);
        return deposit(vault, to, amount, minSharesOut);
    }

    /// @notice Requests that the manager prepare funds for withdrawal next cycle
    /// @notice Invoking this function when sender already has a currently pending request will overwrite that requested amount and reset the cycle timer
    /// @param fromVault Vault from where redeemed shares
    /// @param to At name of who will this be reedem
    /// @param amount Amount of fTokens requested to be redeemed
    function requestReedemShares(
        IERC4626 fromVault,
        address to,
        uint256 amount
    ) external {
        require(ERC20(fromVault.asset()).balanceOf(msg.sender) >= amount);
        fromVault.withdraw(amount,to,msg.sender);
    }

    function reedemShares(
        IERC4626 fromVault,
        address to,
        uint256 amount,
        uint256 minSharesOut
    ) external payable returns (uint256 sharesOut) {
        return withdraw(fromVault, address(to), amount, minSharesOut);
    }

    function redeemToDeposit(
        IERC4626 fromVault,
        IERC4626 toVault,
        address to,
        uint256 shares,
        uint256 minSharesOut
    ) external payable returns (uint256 sharesOut) {
        // amount out passes through so only one slippage check is needed
        uint256 amount = redeem(fromVault, address(this), shares, 0);
        return deposit(toVault, to, amount, minSharesOut);
    }

    function depositMax(
        IERC4626 vault,
        address to,
        uint256 minSharesOut
    ) public payable returns (uint256 sharesOut) {
        ERC20 asset = ERC20(vault.asset());
        uint256 assetBalance = asset.balanceOf(msg.sender);
        uint256 maxDeposit = vault.maxDeposit(to);
        uint256 amount = maxDeposit < assetBalance ? maxDeposit : assetBalance;
        pullToken(asset, amount, address(this));
        return deposit(vault, to, amount, minSharesOut);
    }

    function redeemMax(
        IERC4626 vault,
        address to,
        uint256 minAmountOut
    ) public payable returns (uint256 amountOut) {
        uint256 shareBalance = vault.balanceOf(msg.sender);
        uint256 maxRedeem = vault.maxRedeem(msg.sender);
        uint256 amountShares = maxRedeem < shareBalance
            ? maxRedeem
            : shareBalance;
        return redeem(vault, to, amountShares, minAmountOut);
    }
}
