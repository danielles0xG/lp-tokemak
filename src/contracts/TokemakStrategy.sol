//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/contracts/access/Ownable.sol";
import "@solmate/mixins/ERC4626.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./interfaces/tokemak/Babylonian.sol";
import "./interfaces/tokemak/IRewards.sol";
import "./interfaces/tokemak/IManager.sol";
import "./interfaces/tokemak/ILiquidityPool.sol";

// @title Tokemak's UNI LP auto-compound strategy
// @author Daniel G.
// @notice Basic implementation of harvesting LP token rewards from Tokemak protocol
// @custz is an experimental contract.
contract TokemakStrategy is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    // @dev Staking Assets
    IUniswapV2Pair public underlying;
    IERC20 public tokematAsset;
    IERC20 public wethAsset;

    // @dev Tokemak's contract dependencies
    IRewards public tokemakRwrdContract;
    IManager public tokemakManagerContract;
    ILiquidityPool public tokemakSushiLpPool;

    // @dev UniswapV2 Router
    IUniswapV2Router02 public uniswapV2Router02;

    uint256 internal storedTotalAssets;
    // @notice variables to keep track of stake amounts
    uint256 public stakes;

    // @dev Auto-compound events to store datapoints on chain
    event Deposit(address _investor, uint256 _amount);
    event Stake(address _investor, uint256 _amount);
    event Withdraw(address _investor, uint256 _amount);
    event RequestWithdraw(address _investor, uint256 _amount);

    // @notice Init strategy Tokemak's dependencies
    // @dev Init tokemak dependencies
    // @param _tokemakRwrdContractAddress Tokemak's rewards controller address
    // @param _tokemakManagerContractAddress Tokemak's main manager controller address
    // @param _tokemakSushiLpPoolAddress Tokemak's uniswap LP pool address
    // @param _uniswapV2Router02Address Un
    constructor(
        ILiquidityPool _tokemakSushiLpPoolAddress,
        IRewards _tokemakRwrdContractAddress,
        IManager _tokemakManagerContractAddress,
        IUniswapV2Router02 _uniswapV2Router02Address,
        ERC20 _underlying
    )ERC4626(_underlying,"dTokeVault","dTKV"){
         require(underlying == IUniswapV2Pair(
            IUniswapV2Factory(uniswapV2Router02.factory()).getPair(address(tokematAsset), address(wethAsset))
        ));
        tokemakSushiLpPool = ILiquidityPool(_tokemakSushiLpPoolAddress);
        tokemakRwrdContract = IRewards(_tokemakRwrdContractAddress);
        tokemakManagerContract = IManager(_tokemakManagerContractAddress);
        uniswapV2Router02 = IUniswapV2Router02(_uniswapV2Router02Address);
        wethAsset = IERC20(uniswapV2Router02.WETH());
        tokematAsset = IERC20(tokemakRwrdContract.tokeToken());
    }

    // @notice Deposits Uni LP tokens into contract callable by only owner
    // @dev Only Uni LP tokens for TOKE-ETH LP pool allowed
    // @dev Stakes all its deposits in Tokemak's UNI LP token pool
    // @param amount Amount of UNI LP token to deposit
    function afterDeposit(uint256 /*asset*/, uint256 amount) internal override {
        // @dev stakes all deposits
        storedTotalAssets += amount;
        _stake(amount);
    }

    function totalAssets() public view override returns (uint256){
        return underlying.balanceOf(address(this));
    }

    // @notice Stakes all its deposits in Tokemak's UNI LP token pool
    // @param _amount Amount of UNI LP tokens to stake
    function _stake(uint256 _amount) internal {
        underlying.approve(address(uniswapV2Router02), _amount);
        underlying.approve(address(tokemakSushiLpPool), _amount);
        tokemakSushiLpPool.deposit(_amount);
        emit Stake(_msgSender(), _amount);
    }

    function rewardsSigner() external returns (address) {
        return tokemakRwrdContract.rewardsSigner();
    }

    // @notice Claim Tokemak's rewards in Toke Asset for being LP
    // @param recipient Struct:
    //        chainId, cycle (epochs for funds management), wallet address, claim amount
    // @param v ECDSA signature v,
    // @param r ECDSA signature r,
    // @param s ECDSA signature s,
    function _claim(
        IRewards.Recipient calldata recipient,
        uint8 v,
        bytes32 r,
        bytes32 s // bytes calldata signature
    ) internal {
        tokemakRwrdContract.claim(recipient, v, r, s);
    }

    // @notice Get current claimable token rewards amount
    // @return amount to claim in the current cycle
    function _getClaimableAmount(IRewards.Recipient calldata recipient) internal returns (uint256) {
        return tokemakRwrdContract.getClaimableAmount(recipient);
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
    function autoCompoundWithPermit(IRewards.Recipient calldata recipient, uint8 v, bytes32 r, bytes32 s) external {
        // @dev 1.- Check for positive amount of toke rewards in current cycle
        uint256 claimableRwrds = _getClaimableAmount(recipient);
        uint256 tokemakBalance;

        // @dev 2.- Claim TOKE rewards
        if (claimableRwrds > 0) {
            _claim(recipient, v, r, s);
            tokemakBalance = tokematAsset.balanceOf(address(this));
            require(tokemakBalance >= claimableRwrds, "TUniLPS 05: Rewards claim failed.");
        }
        // @dev 3.- Swap needed amount of total TOKE rewards to form token pair TOKE-ETH
        _balanceLiquidity(tokemakBalance);

        uint256 wethBalance = wethAsset.balanceOf(address(this));
        // @dev 4.- Provide liquidity to UniswapV2 to TOKE-ETH pool
        (, , uint256 lpAmount) = addLiquidity(address(tokematAsset), address(wethAsset), tokemakBalance, wethBalance);
        // @dev 5.- Stake UNIV2 LP Token into TOKEMAK Uni LP Token Pool
        if (lpAmount > 0) _stake(lpAmount);
    }

    // @notice Buy needed WETHc to form token pair TOKE-ETH
    // @param _amount of weth to buy
    // @return Weth amount bought
    function _balanceLiquidity(uint256 _amount) internal returns (uint256) {
        (uint256 reserveA, , ) = IUniswapV2Pair(underlying).getReserves();

        // @dev ondo.fi use of Zapper's Babylonian function to balance amount of assets for LP pool
        uint256 amountToSwap = calculateSwapInAmount(reserveA, _amount);
        address[] memory path = new address[](2);
        path[0] = address(tokematAsset);
        path[1] = address(wethAsset);

        return swapExactTokens(amountToSwap, 0, path);
    }

    // @notice Swaps an exact amount of input tokens for as many output tokens as possible,
    // @param amountIn Amount of input tokens to send
    // @param amountOutMin Minimum amount of output tokens to receive and avoid tx revert
    // @param path Array of toke addresses, single hop swapping path
    function swapExactTokens(uint256 amountIn, uint256 amountOutMin, address[] memory path) internal returns (uint256) {
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
    function calculateSwapInAmount(uint256 reserveIn, uint256 userIn) public pure returns (uint256) {
        return (Babylonian.sqrt(reserveIn * (userIn * 3988000 + reserveIn * 3988009)) - reserveIn * 1997) / 1994;
    }

    // @notice Uniswapv2 function to add liquidity to existing pool
    // @param tokenA 1st pair asset address
    // @param tokenB 2nd pair asset address
    // @param amount0 Aount of 1st pair asset to add as liquidity
    // @param amount1 Amount of 2nd pair asset to add as liquidity
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amount0,
        uint256 amount1
    ) public returns (uint256 out0, uint256 out1, uint256 lp) {
        IERC20(tokenA).approve(address(uniswapV2Router02), amount0);
        IERC20(tokenB).approve(address(uniswapV2Router02), amount1);
        (out0, out1, lp) = uniswapV2Router02.addLiquidity(
            tokenA,
            tokenB,
            amount0,
            amount1,
            0,
            0,
            msg.sender,
            block.timestamp
        );
    }

    // function addLiquidityETH(
    //   address token,
    //   uint amountTokenDesired,
    //   uint amountTokenMin,
    //   uint amountETHMin,
    //   address to,
    //   uint deadline
    // ) external payable returns (uint amountToken, uint amountETH, uint liquidity){

    // }

    // @notice Request anticipated withdrawal to Tokemak's Uni LP pool
    // @dev Request will be served on next cycle (currently 7 days)
    function requestWithdrawal(uint256 _amount) public {
        require(_amount <= stakes, " TUniLPS 06: insufficient funds to withdraw.");
        tokemakSushiLpPool.requestWithdrawal(_amount);
        emit RequestWithdraw(_msgSender(), _amount);
    }

    function currentCycle() external view returns (uint256 _cycle) {
        _cycle = tokemakManagerContract.getCurrentCycle();
    }

    // @notice Withdrawal Tokemak's Uni LP tokens
    function withdraw(uint256 _amount) public {
        (uint256 minCycle, ) = tokemakSushiLpPool.requestedWithdrawals(_msgSender());
        require(minCycle > tokemakManagerContract.getCurrentCycleIndex(), "TUniLPS 07: Withdrawal not yet available.");
        require(_amount <= stakes, "TUniLPS 08: insufficient funds to withdraw.");
        stakes -= _amount;
        tokemakSushiLpPool.withdraw(_amount);
        emit Withdraw(_msgSender(), _amount);
    }

    // @notice Returns chain Id
    function _getChainID() private view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }

    function tokeToken() public returns (IERC20) {
        return tokemakRwrdContract.tokeToken();
    }
}
