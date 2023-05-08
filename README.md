# Tokemak SUSHI LP Reactor strategy

#### Sushi/Tokemak Liquidity staking vault 

Liquidity Staking is the process of staking the liquidity you add to the SushiSwap pools (either ETH pool or Toke pool) and earning TOKE rewards in return.

This is ERC4626 vault implementation to tokenize the liquidity provision as ERC20 shares to depositors.

- **Reactor Current stats:** $5.3M TVL | 16.6% APR
- **Reactor address**: [0x8858A739eA1dd3D80FE577EF4e0D03E88561FaA3](https://etherscan.io/address/0x8858A739eA1dd3D80FE577EF4e0D03E88561FaA3)
- **Reactor website:** Visit [tokemak](https://app.tokemak.xyz/) dashboard.

**Strategy Steps:**

- Provide liquidity in sushi swap for weth/toke and stake lp into tokemak reactor for 7 days cycle rewards.
- Claim rewards in TOKE and swap half/balanced amount for WETH.
- Provide more liquidity  weth/toke to sushiswap out of TOKE rewards.
- Auto compound
- Repeat if rewards treshhold is met

**Install**

`````
forge build
`````