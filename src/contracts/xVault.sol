//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "@openzeppelin-contracts/contracts/access/Ownable.sol";
import "@solmate/mixins/ERC4626.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./interfaces/tokemak/Babylonian.sol";
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

    /// @notice pool asset cap
    uint256 private maxPoolLimit;    
    
    /// @notice the maximum length of a rewards cycle
    uint32 public immutable rewardsCycleLength;

    /// @notice the effective start of the current cycle
    uint32 public lastSync;

    /// @notice the end of the current cycle. Will always be evenly divisible by `rewardsCycleLength`.
    uint32 public rewardsCycleEnd;

    /// @notice the amount of rewards distributed in a the most recent cycle.
    uint192 public lastRewardAmount;


    // @dev Auto-compound events to store datapoints on chain
    event Deposit(address indexed investor, uint256 _amount);
    event Stake(address indexed investor, uint256 _amount);
    event Withdraw(address indexed investor, uint256 _amount);
    event RequestWithdraw(address indexed investor, uint256 _amount);
    event NewRewardsCycle(uint32 indexed cycleEnd, uint256 rewardAmount);


    error RequestWithdrawError();
    error InvalidSigError();
    error SyncError();

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
        tokematAsset = IERC20(tokemakRewards.tokeToken());
        rewardsCycleLength = _rewardsCycleLength;
        // seed initial rewardsCycleEnd
        rewardsCycleEnd = (block.timestamp.safeCastTo32() / rewardsCycleLength) * rewardsCycleLength;
    
    }

    receive() payable external{
        revert("Unsupported");
    }
    fallback() external{
        console.log("msg sender: ",msg.sender);
        revert("Unsupported");
    }

    function setPoolLimit(uint256 _newLimit) external onlyOwner {
        require(_newLimit != 0, "DNP: zero amount");
        maxPoolLimit = _newLimit;
    }

    // @notice Auto-compound call to claim and re-stake rewards
    // @dev Function call execute the following steps:
    // @dev 1.- Check for positive amount of toke rewards in current cycle
    // @dev 2.- Claim TOKE rewards
    // @dev 3.- Swap needed amount of total TOKE rewards to form token pair TOKE-ETH
    // @dev 4.- Provide liquidity to UniswapV2 to TOKE-ETH pool & Receive UNIV2 LP Token
    // @dev 5.- Stake UNIV2 LP Token into TOKEMAK Uni LP Token Pool
    // @param v ECDSA signature,
    // @param r ECDSA signature,
    // @param s ECDSA signature,
    function autoCompoundWithPermit(
        IRewards.Recipient calldata recipient,
        bytes calldata stratConfig,
        uint8 v, bytes32 r, bytes32 s) external {
        // @dev 1.- Check for positive amount of toke rewards in current cycle
        uint256 claimableRwrds = _getClaimableAmount(recipient);
        (uint256 lpAmountAMin,uint256 lpAmountBMin, uint256 swapWethMinOut) = abi.decode(stratConfig, (uint256,uint256,uint256));
        uint256 tokemakBalance;
        

        // @dev 2.- Claim TOKE rewards
        if (claimableRwrds > 0) {
            _claim(recipient,v,r,s);
            tokemakBalance = tokematAsset.balanceOf(address(this));
            require(tokemakBalance >= claimableRwrds, "TUniLPS 05: Rewards claim failed.");
        }
        // @dev 3.- Swap needed amount of total TOKE rewards to form token pair TOKE-ETH
        _balanceLiquidity(tokemakBalance,swapWethMinOut);

        uint256 wethBalance = wethAsset.balanceOf(address(this));

        // @dev 4.- Provide liquidity to UniswapV2 to TOKE-ETH pool
        (, , uint256 lpAmount) = _addLiquidity(address(tokematAsset), address(wethAsset), tokemakBalance, wethBalance,lpAmountAMin,lpAmountBMin);
        // @dev 5.- Stake UNIV2 LP Token into TOKEMAK Uni LP Token Pool
        if (lpAmount > 0) _stake(lpAmount);
    }

    // @notice Request anticipated withdrawal to Tokemak's Uni LP pool
    // @dev Request will be served on next cycle (currently 7 days)
    function requestWithdrawal(uint256 amount) external {
        if(!(amount <= totalAssets())) revert RequestWithdrawError();
        tokemakSushiReactor.requestWithdrawal(amount);
        emit RequestWithdraw(_msgSender(), amount);
    }


    /// @notice Compute the amount of tokens available to share holders.
    ///         Increases linearly during a reward distribution period from the sync call, not the cycle start.
    function totalAssets() public view override returns (uint256) {
        // cache global vars
        uint256 storedTotalAssets_ = storedTotalAssets;
        uint192 lastRewardAmount_ = lastRewardAmount;
        uint32 rewardsCycleEnd_ = rewardsCycleEnd;
        uint32 lastSync_ = lastSync;

        if (block.timestamp >= rewardsCycleEnd_) {
            // no rewards or rewards fully unlocked
            // entire reward amount is available
            return storedTotalAssets_ + lastRewardAmount_;
        }

        // rewards not fully unlocked
        // add unlocked rewards to stored total
        uint256 unlockedRewards = (lastRewardAmount_ * (block.timestamp - lastSync_)) / (rewardsCycleEnd_ - lastSync_);
        return storedTotalAssets_ + unlockedRewards;
    }

    /// @notice Distributes rewards to xERC4626 holders.
    /// All surplus `asset` balance of the contract over the internal balance becomes queued for the next cycle.
    function syncRewards() public virtual{
        uint192 lastRewardAmount_ = lastRewardAmount;
        uint32 timestamp = block.timestamp.safeCastTo32();

        if (timestamp < rewardsCycleEnd) revert SyncError();

        uint256 storedTotalAssets_ = storedTotalAssets;
        uint256 nextRewards = tokematAsset.balanceOf(address(this)) - storedTotalAssets_ - lastRewardAmount_;

        storedTotalAssets = storedTotalAssets_ + lastRewardAmount_; // SSTORE

        uint32 end = ((timestamp + rewardsCycleLength) / rewardsCycleLength) * rewardsCycleLength;

        // Combined single SSTORE
        lastRewardAmount = nextRewards.safeCastTo192();
        lastSync = timestamp;
        rewardsCycleEnd = end;

        emit NewRewardsCycle(end, nextRewards);
    }

    // @notice Withdrawal Tokemak's Uni LP tokens
    function beforeWithdraw(uint256 amount, uint256 /*shares*/) internal override {
        (uint256 minCycle, ) = tokemakSushiReactor.requestedWithdrawals(_msgSender());
        require(minCycle > tokemakManager.getCurrentCycleIndex(), "TUniLPS 07: Withdrawal not yet available.");
        require(amount <= storedTotalAssets, "TUniLPS 08: insufficient funds to withdraw.");
        storedTotalAssets -= amount;
        tokemakSushiReactor.withdraw(amount);
        storedTotalAssets -= amount;
        emit Withdraw(_msgSender(),amount);
    }

    function deposit(uint256 amount, address receiver) public override returns (uint256 shares) {
            require(amount > 0,"TLPV::deposit:InvalidAmount");
            require(address(receiver) != address(0x0),"TLPV::deposit:InvalidAddress");
            super.deposit(amount,receiver);
    }
    
    // @notice Deposits Uni LP tokens into contract callable by only owner
    // @dev Only Uni LP tokens for TOKE-ETH LP pool allowed
    // @dev Stakes all its deposits in Tokemak's UNI LP token pool
    // @param amount Amount of UNI LP token to deposit
    function afterDeposit(uint256 /*asset*/, uint256 amount) internal override {
        if(storedTotalAssets >= maxPoolLimit)
        SafeERC20.safeIncreaseAllowance(IERC20(address(asset)), address(tokemakSushiReactor), amount);
        storedTotalAssets += amount;
       _stake(amount);
    }

    function _stake(uint256 amount) internal {
        tokemakSushiReactor.deposit(amount);
        emit Stake(_msgSender(), amount);
    }

    // @notice Claim Tokemak's rewards in Toke Asset for being LP
    // @param recipient Struct:
    //        chainId, cycle (epochs for funds management), wallet address, claim amount
    // @param v ECDSA signature v,
    // @param r ECDSA signature r,
    // @param s ECDSA signature s,
    function _claim(
        IRewards.Recipient calldata recipient,
        uint8 v, bytes32 r, bytes32 s
    ) internal {
        tokemakRewards.claim(recipient, v, r, s);
    }

    // @notice Get current claimable token rewards amount
    // @return amount to claim in the current cycle
    function _getClaimableAmount(IRewards.Recipient calldata recipient) internal returns (uint256) {
        return tokemakRewards.getClaimableAmount(recipient);
    }


    // @notice Buy needed WETHc to form token pair TOKE-ETH
    // @param _amount of weth to buy
    // @return Weth amount bought
    function _balanceLiquidity(uint256 _amount,uint256 swapAmountOut) internal returns (uint256) {
        (uint256 reserveA, , ) = IUniswapV2Pair(address(asset)).getReserves();

        // @dev ondo.fi use of Zapper's Babylonian function to balance amount of assets for LP pool
        uint256 amountToSwap = _calculateSwapInAmount(reserveA, _amount);

        address[] memory path = new address[](2);
        path[0] = address(tokematAsset);
        path[1] = address(wethAsset);

        return _swapExactTokens(amountToSwap, swapAmountOut, path);
    }

    // @notice Swaps an exact amount of input tokens for as many output tokens as possible,
    // @param amountIn Amount of input tokens to send
    // @param amountOutMin Minimum amount of output tokens to receive and avoid tx revert
    // @param path Array of toke addresses, single hop swapping path
    function _swapExactTokens(uint256 amountIn, uint256 amountOutMin, address[] memory path) internal returns (uint256) {
        IERC20(tokematAsset).approve(address(uniswapV2Router02), amountIn);
        return
            uniswapV2Router02.swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), block.timestamp)[
                path.length - 1
            ];
    }

    // @notice Exactly how much of userIn to swap to get perfectly balanced ratio for LP tokens
    // @dev This function is a Reused calculation from Ondo.fi sushistaking v2 strategy
    // @dev This code is cloned from L1242-1253 of UniswapV2_ZapIn_General_V4 at https://etherscan.io/address/0x5ACedBA6C402e2682D312a7b4982eda0Ccf2d2E3#code#L1242
    // @param reserveIn Amount of reserves for asset 0
    // @param userIn Availabe amount of asset 0 to swap
    // @return Amount of userIn to swap for asset 1
    function _calculateSwapInAmount(uint256 reserveIn, uint256 userIn) internal view returns (uint256) {
        console.log("uint256 reserveIn, uint256 userIn: ", reserveIn, userIn);
        return (Babylonian.sqrt(reserveIn * (userIn * 3988000 + reserveIn * 3988009)) - reserveIn * 1997) / 1994;
    }

    function _splitSign(bytes memory sig) internal pure returns(bytes32 r, bytes32 s, uint8 v){
        if(sig.length != 65) revert InvalidSigError();
        // first 32 bytes is the lenght of sig, we skip it
        assembly{
            r:= mload(add(sig,32))  // add to the pointer of sig to next 32 bytes
            s := mload(add(sig,64)) // add to the pointer of sig to next 32 bytes to 64
            v := byte(0, mload(add(sig,96)))
        }
    }

    // @notice Uniswapv2 function to add liquidity to existing pool
    // @param tokenA 1st pair asset address
    // @param tokenB 2nd pair asset address
    // @param amount0 Aount of 1st pair asset to add as liquidity
    // @param amount1 Amount of 2nd pair asset to add as liquidity
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amount0,
        uint256 amount1,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 out0, uint256 out1, uint256 lp) {
        IERC20(tokenA).approve(address(uniswapV2Router02), amount0);
        IERC20(tokenB).approve(address(uniswapV2Router02), amount1);
        (out0, out1, lp) = uniswapV2Router02.addLiquidity(
            tokenA,
            tokenB,
            amount0,
            amount1,
            amountAMin,
            amountBMin,
            msg.sender,
            block.timestamp
        );
    }
}
