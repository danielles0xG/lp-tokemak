# Tokemak SUSHI LP Reactor strategy

#### Ethereum Mainnet auto compound Toke rewards to provide lp to reactor
**Reactor Current stats:** $5.3M TVL | 16.6% APR
**Reactor address**: [0x8858A739eA1dd3D80FE577EF4e0D03E88561FaA3](https://etherscan.io/address/0x8858A739eA1dd3D80FE577EF4e0D03E88561FaA3)
**Reavtor website:** Visit [tokemak](https://app.tokemak.xyz/) dashboard.

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