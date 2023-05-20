//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "@openzeppelin-contracts/contracts/access/Ownable.sol";
import "@solmate/mixins/ERC4626.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./interfaces/tokemak/IRewards.sol";
import "./interfaces/tokemak/IManager.sol";
import "./interfaces/tokemak/ILiquidityPool.sol";
import "solmate/utils/SafeCastLib.sol";
import "forge-std/Test.sol";

// @title Tokemak's UNI LP auto-compound strategy
// @author Daniel G.
// @notice Basic implementation of harvesting LP token rewards from Tokemak protocol
// @custz is an experimental contract.
contract xVault is ERC4626, Ownable {
    using SafeCastLib for *;

    // @dev Staking Assets
    IERC20 private tokematAsset;
    IERC20 private wethAsset;

    // @dev Tokemak's contract dependencies
    IRewards private tokemakRewards;
    IManager private tokemakManager;
    ILiquidityPool private tokemakSushiReactor;
    IUniswapV2Router02 private uniswapV2Router02;

    /// @notice internal accounting
    uint256 private storedTotalAssets;

    /// @notice the maximum length of a rewards cycle
    uint32 public immutable rewardsCycleLength;

    /// @notice the effective start of the current cycle
    uint32 public lastSync;

    /// @notice the end of the current cycle. Will always be evenly divisible by `rewardsCycleLength`.
    uint32 public rewardsCycleEnd;

    /// @notice the amount of rewards distributed in a the most recent cycle.
    uint192 public lastRewardAmount;

    // @dev Auto-compound events to store datapoints on chain
    event DepositEvent(address indexed investor, uint256 _amount);
    event StakeEvent(address indexed investor, uint256 _amount);
    event WithdrawEvent(address indexed investor, uint256 _amount);
    event RequestWithdraw(address indexed investor, uint256 _amount);
    event SetPoolLimit(uint256 _newLimit);
    event NewRewardsCycle(uint32 indexed cycleEnd, uint256 rewardAmount);

    error RequestWithdrawError();
    error InvalidSigError();
    error SyncError();
    error RwrdClaimError();

    // @notice Init strategy Tokemak's dependencies
    // @dev Init tokemak dependencies
    // @param _tokemakRewardsAddress Tokemak's rewards controller address
    // @param _tokemakManagerAddress Tokemak's main manager controller address
    // @param _tokemakSushiReactorAddress Tokemak's uniswap LP pool address
    // @param _sushiSwapV2Router02Address Un
    constructor(
        ILiquidityPool _tokemakSushiReactorAddress,
        IRewards _tokemakRewardsAddress,
        IManager _tokemakManagerAddress,
        IUniswapV2Router02 _sushiSwapV2Router02Address,
        ERC20 _underlying,
        uint32 _rewardsCycleLength
    ) ERC4626(_underlying, "dTokeVault", "dTKV") {
        require(address(_underlying) != address(0), "address zero");
        tokemakSushiReactor = ILiquidityPool(_tokemakSushiReactorAddress);
        tokemakRewards = IRewards(_tokemakRewardsAddress);
        tokemakManager = IManager(_tokemakManagerAddress);
        uniswapV2Router02 = IUniswapV2Router02(_sushiSwapV2Router02Address);
        wethAsset = IERC20(uniswapV2Router02.WETH());
        tokematAsset = tokemakRewards.tokeToken();
        rewardsCycleLength = _rewardsCycleLength;
    }

    receive() external payable {
        revert("Unsupported");
    }

    fallback() external {
        revert("Unsupported");
    }

    // @notice Auto-compound call to claim and re-stake rewards
    // @dev Function call execute the following steps:
    // @dev 1.- Check for positive amount of toke rewards in current cycle
    // @dev 2.- Claim TOKE rewards
    // @dev 2.- Stake TOKE rewards
    // @param v ECDSA signature,
    // @param r ECDSA signature,
    // @param s ECDSA signature,
    function autoCompoundWithPermit(
        IRewards.Recipient calldata recipient,
        bytes calldata swapConfig,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // @dev 1.- Check for positive amount of toke rewards in current cycle
        uint256 claimableRwrds = _getClaimableAmount(recipient);
        (uint256 swapOutMin) = abi.decode(swapConfig, (uint256));
        uint256 tokemakBalance;

        // @dev 2.- Claim TOKE rewards
        if (claimableRwrds > 0) {
            _claim(recipient, v, r, s);
            tokemakBalance = tokematAsset.balanceOf(address(this));
            if (!(tokemakBalance >= claimableRwrds)) revert RwrdClaimError();
            // swap token TOKE for underlying(LP SUHI) and deposit
            uint256 lpFromRwrds = _swapExactTokens(tokemakBalance, swapOutMin);
            _stake(tokemakBalance);
        }
    }

    // @notice Request anticipated withdrawal to Tokemak's Uni LP pool
    // @dev Request will be served on next cycle (currently 7 days)
    function requestWithdrawal(uint256 amount) external {
        console.log("amount: ",amount);
        require(amount <= IERC20(address(this)).balanceOf(msg.sender),"Inssuficient balance");
        require(amount <= totalAssets(),"amount > totalAssets");
        tokemakSushiReactor.requestWithdrawal(amount);
        emit RequestWithdraw(_msgSender(), amount);
    }

    /// @notice Compute the amount of tokens available to share holders.
    ///  Increases linearly during a reward distribution period from the sync call, not the cycle start.
    function totalAssets() public view override returns (uint256) {
        return storedTotalAssets;
    }

    /// @notice Distributes rewards to xERC4626 holders.
    /// All surplus `asset` balance of the contract over the internal balance becomes queued for the next cycle.
    function syncRewards() public virtual {
        uint192 lastRewardAmount_ = lastRewardAmount;
        uint32 timestamp = block.timestamp.safeCastTo32();

        if (timestamp < rewardsCycleEnd) revert SyncError();

        uint256 storedTotalAssets_ = storedTotalAssets;
        uint256 nextRewards = tokematAsset.balanceOf(address(this)) - storedTotalAssets_ - lastRewardAmount_;

        storedTotalAssets = storedTotalAssets_ + lastRewardAmount_; // SSTORE

        uint32 end = (((timestamp + rewardsCycleLength) * rewardsCycleLength) / rewardsCycleLength);
        // Combined single SSTORE
        lastRewardAmount = nextRewards.safeCastTo192();
        lastSync = timestamp;
        rewardsCycleEnd = end;

        emit NewRewardsCycle(end, nextRewards);
    }

    // @notice Withdrawal Tokemak's Uni LP tokens
    function beforeWithdraw(uint256 amount, uint256 /*shares*/) internal override {
        (uint256 minCycle, ) = tokemakSushiReactor.requestedWithdrawals(_msgSender());
        require(minCycle > tokemakManager.getCurrentCycleIndex(), "xVault:not min cycle");
        require(amount <= storedTotalAssets, "xVault:insufficient funds");
        storedTotalAssets -= amount;
        tokemakSushiReactor.withdraw(amount);
        emit WithdrawEvent(_msgSender(), amount);
    }

    function deposit(uint256 amount, address receiver) public override returns (uint256 shares) {
        require(amount > 0, "deposit:InvalidAmount");
        require(address(receiver) != address(0x0), "deposit:address zero");
        super.deposit(amount, receiver);
    }

    /// @notice Deposits Uni LP tokens into contract callable by only owner
    /// @dev Stakes all its deposits in Tokemak's SUSHI LP token pool for toke rewards
    /// @param amount Amount of UNI LP token to deposit
    function afterDeposit(uint256 /*asset*/, uint256 amount) internal override {
        SafeERC20.safeIncreaseAllowance(IERC20(address(asset)), address(tokemakSushiReactor), amount);
        storedTotalAssets += amount;
        _stake(amount);
        emit DepositEvent(_msgSender(), amount);
    }

    /// @notice stakes TOKE rewards from SUSHI LP
    function _stake(uint256 amount) internal {
        SafeERC20.safeIncreaseAllowance(IERC20(address(asset)), address(tokemakSushiReactor), amount);
        tokemakSushiReactor.deposit(amount);
        emit StakeEvent(_msgSender(), amount);
    }

    // @notice Claim Tokemak's rewards in Toke Asset for being LP
    // @param recipient Struct:
    //        chainId, cycle (epochs for funds management), wallet address, claim amount
    // @param v ECDSA signature v,
    // @param r ECDSA signature r,
    // @param s ECDSA signature s,
    function _claim(IRewards.Recipient calldata recipient, uint8 v, bytes32 r, bytes32 s) internal {
        tokemakRewards.claim(recipient, v, r, s);
    }

    // @notice Get current claimable token rewards amount
    // @return amount to claim in the current cycle
    function _getClaimableAmount(IRewards.Recipient calldata recipient) internal returns (uint256) {
        return tokemakRewards.getClaimableAmount(recipient);
    }

    // @notice Swaps an exact amount of input tokens for as many output tokens as possible,
    // @param amountIn Amount of input tokens to send
    // @param amountOutMin Minimum amount of output tokens to receive and avoid tx revert
    // @param path Array of toke addresses, single hop swapping path
    function _swapExactTokens(
        uint256 amountIn,
        uint256 amountOutMin
    ) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(tokematAsset);
        path[1] = address(asset);
        require(IERC20(tokematAsset).approve(address(uniswapV2Router02), amountIn));
        return
            uniswapV2Router02.swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), block.timestamp)[
                path.length - 1
            ];
    }
}
