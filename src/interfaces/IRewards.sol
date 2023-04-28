// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IRewards {
    // function claimedAmounts(address _account) external returns (uint256);

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    struct Recipient {
        uint256 chainId;
        uint256 cycle;
        address wallet;
        uint256 amount;
    }

    function rewardsSigner() external returns (address _rewardsSigner);

    function tokeToken() external returns (IERC20);

    function getClaimableAmount(Recipient calldata recipient)
        external
        returns (uint256);

    function claim(
        Recipient calldata recipient,
        uint8 v,
        bytes32 r,
        bytes32 s // bytes calldata signature
    ) external;
}
