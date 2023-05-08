# Tokemak SUSHI LP Reactor strategy


[Tokemak](https://docs.tokemak.xyz/) is a novel protocol designed to generate deep, sustainable liquidity for DeFi and future tokenized applications that will arise throughout the growth and evolution of web3. 

---------------------------------------
#### Sushi/Tokemak Liquidity staking vault 

This is an ERC4626 vault implementation to tokenize the TOKE/ETH liquidity provision as ERC20 shares to depositors.

##### ERC4626 Ecosystem Utilities

Router Implementation example from [Fei protocol](https://github.com/fei-protocol/ERC4626.git).

This repository contains open-source ERC4626 infrastructure that can be used by solidity developers using [EIP-4626](https://eips.ethereum.org/EIPS/eip-4626), including ERC4626Router (the canonical ERC-4626 multicall router) and xERC4626. Powered by [forge](https://github.com/gakonst/foundry/tree/master/forge) and [solmate](https://github.com/Rari-Capital/solmate).

- **Reactor Current stats:** $5.3M TVL | 16.6% APR
- **Reactor address**: [0x8858A739eA1dd3D80FE577EF4e0D03E88561FaA3](https://etherscan.io/address/0x8858A739eA1dd3D80FE577EF4e0D03E88561FaA3)
- **Reactor website:** Visit [tokemak](https://app.tokemak.xyz/) dashboard.

**Strategy Steps:**

- Provide liquidity in sushi swap for weth/toke and stake lp into tokemak reactor for 7 days cycle rewards.
- Automatic claim rewards in TOKE and swap half/balanced amount for WETH.
- Provide more liquidity  weth/toke to sushiswap out of TOKE rewards.
- Reedem rewards, (compound) and provide more liquidity
- Repeat if rewards tresh hold is met

**Install**


`````
forge build
`````

**Test**
  `````
  forge test
  `````

**Integration E2e test**

- require ethereum mainnet rpc node url variable at .env file
`````
RPC_MAINNET=<https://rpc.url.exaple>
