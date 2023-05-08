//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;
import "@solmate/mixins/ERC4626.sol";
import "@solmate/utils/SafeTransferLib.sol";

contract StrategyMock is ERC4626 {
    using SafeTransferLib for *;
    ERC20 public undelying;

    constructor(ERC20 _asset) ERC4626(_asset, "StratShares", "STSH") {
        undelying = _asset;
    }

    function deposit(
        uint256 amount,
        address receiver
    ) public override returns (uint256) {
        return super.deposit(amount, receiver);
    }

    function withdraw(
        uint256 amount,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {
        shares = super.withdraw(amount, receiver, owner);
    }

    function totalAssets() public view override returns (uint256) {
        return undelying.balanceOf(address(this));
    }

    function mint(address to, uint256 shares) external {
        _mint(to, shares);
    }
}
