# Securo Finance

## Products

### Blockchain Network Index (BNI)

Blockchain Network is a tokenised crypto index fund which tracks major Layer 1 Blockchain Network utility tokens, such as AVAX, NEAR, MATIC. An innovative fund to get ahead of the crypto market.

### Low-risk Crypto Index (LCI)

Low-risk Crypto Index is a tokenised crypto index fund which tracks major stablecoins, such as USDC, USDT, DAI. Low risk but stable profit in your portfolio.

### Market Weighted Index (MWI)

Market Weighted Index is a tokenised crypto index fund which tracks major crypto assets, such as Bitcoin, Ethereum, DAI. A secure way to earn profit with bitcoin and top cryptocurrencies.

### Staking Index (STI)

## Environment

Create files storing private key and API keys.


## Deploy and Verify contracts

### BNI
```text
npx hardhat deploy --network auroraMainnet --tags auroraMainnet_bni
npx hardhat deploy --network avaxMainnet --tags avaxMainnet_bni
npx hardhat deploy --network maticMainnet --tags maticMainnet_bni
```

```text
npx hardhat run --network auroraMainnet ./scripts/deploy/config_BNIUserAgent.js
npx hardhat run --network avaxMainnet ./scripts/deploy/config_BNIUserAgent.js
npx hardhat run --network maticMainnet ./scripts/deploy/config_BNIUserAgent.js
```

### LCI
```text
npx hardhat deploy --network bscMainnet --tags bscMainnet_lci
```

### MWI
```text
npx hardhat deploy --network avaxMainnet --tags avaxMainnet_mwi
```

### STI
```text
npx hardhat deploy --network auroraMainnet --tags auroraMainnet_sti
npx hardhat deploy --network avaxMainnet --tags avaxMainnet_sti
npx hardhat deploy --network bscMainnet --tags bscMainnet_sti
npx hardhat deploy --network ethMainnet --tags ethMainnet_sti
```

```text
npx hardhat run --network auroraMainnet ./scripts/deploy/config_STIUserAgent.js
npx hardhat run --network avaxMainnet ./scripts/deploy/config_STIUserAgent.js
npx hardhat run --network bscTestnet ./scripts/deploy/config_STIUserAgent.js
npx hardhat run --network ethMainnet ./scripts/deploy/config_STIUserAgent.js
```

### Cross-chain adapters
```text
npx hardhat run --network auroraMainnet ./scripts/deploy/config_xchain.js
npx hardhat run --network avaxMainnet ./scripts/deploy/config_xchain.js
npx hardhat run --network bscMainnet ./scripts/deploy/config_xchain.js
npx hardhat run --network ethMainnet ./scripts/deploy/config_xchain.js
npx hardhat run --network maticMainnet ./scripts/deploy/config_xchain.js
```

## Contracts

### Tokens

#### USDT

| Network     | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Aurora           | [0x4988a896b1227218e4A686fdE5EabdcAbd91571f](https://aurorascan.dev/address/0x4988a896b1227218e4A686fdE5EabdcAbd91571f) | [0xF9C249974c1Acf96a59e5757Cc9ba7035cE489B1](https://testnet.aurorascan.dev/address/0xf9c249974c1acf96a59e5757cc9ba7035ce489b1)
| Avalanche        | [0xc7198437980c041c805A1EDcbA50c1Ce5db95118](https://snowtrace.io/address/0xc7198437980c041c805A1EDcbA50c1Ce5db95118) | [0x78ae2880bd1672b49a33cF796CF53FE6db0aB01D](https://testnet.snowtrace.io/address/0x78ae2880bd1672b49a33cf796cf53fe6db0ab01d)
| BSC              | [0x55d398326f99059fF775485246999027B3197955](https://bscscan.com/token/0x55d398326f99059fF775485246999027B3197955) | [0x1F326a8CA5399418a76eA0efa0403Cbb00790C67](https://testnet.bscscan.com/address/0x1f326a8ca5399418a76ea0efa0403cbb00790c67)
| Ethereum         | [0xdAC17F958D2ee523a2206206994597C13D831ec7](https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7) | [0x21e48034753E490ff04f2f75f7CAEdF081B320d5](https://rinkeby.etherscan.io/address/0x21e48034753e490ff04f2f75f7caedf081b320d5)
| Polygon          | [0xc2132D05D31c914a87C6611C10748AEb04B58e8F](https://polygonscan.com/address/0xc2132D05D31c914a87C6611C10748AEb04B58e8F) | [0x7e4C234B1d634DB790592d1550816b19E862F744](https://mumbai.polygonscan.com/address/0x7e4c234b1d634db790592d1550816b19e862f744)

#### Used tokens

| Network     | Mainnet                                                                                                               | Testnet                                                                                                               |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| BSTN on Aurora (reward)       | [0x9f1F933C660a1DC856F0E0Fe058435879c5CCEf0](https://aurorascan.dev/address/0x9f1F933C660a1DC856F0E0Fe058435879c5CCEf0) |
| cNEAR on Aurora               | [0x8C14ea853321028a7bb5E4FB0d0147F183d3B677](https://aurorascan.dev/address/0x8C14ea853321028a7bb5E4FB0d0147F183d3B677) |
| LP BSTN-WNEAR on Aurora       | [0xBBf3D4281F10E537d5b13CA80bE22362310b2bf9](https://aurorascan.dev/address/0xBBf3D4281F10E537d5b13CA80bE22362310b2bf9) |
| LP WNEAR-USDC on Aurora       | [0x20F8AeFB5697B77E0BB835A8518BE70775cdA1b0](https://aurorascan.dev/address/0x20F8AeFB5697B77E0BB835A8518BE70775cdA1b0) |
| LP WNEAR-USDT on Aurora       | [0x03B666f3488a7992b2385B12dF7f35156d7b29cD](https://aurorascan.dev/address/0x03B666f3488a7992b2385B12dF7f35156d7b29cD) |
| META on Aurora (reward)       | [0xc21Ff01229e982d7c8b8691163B0A3Cb8F357453](https://aurorascan.dev/address/0xc21Ff01229e982d7c8b8691163B0A3Cb8F357453) |
| stNEAR on Aurora              | [0x07F9F7f963C5cD2BBFFd30CcfB964Be114332E30](https://aurorascan.dev/address/0x07F9F7f963C5cD2BBFFd30CcfB964Be114332E30) |
| WNEAR on Aurora               | [0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d](https://aurorascan.dev/address/0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d) |
| aAvaWAVAX on Avalanche        | [0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97](https://snowtrace.io/address/0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97) |
| aAvaWBTC on Avalanche         | [0x078f358208685046a11C85e8ad32895DED33A249](https://snowtrace.io/address/0x078f358208685046a11C85e8ad32895DED33A249) |
| aAvaWETH on Avalanche         | [0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8](https://snowtrace.io/address/0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8) |
| aAvaUSDT on Avalanche         | [0x6ab707Aca953eDAeFBc4fD23bA73294241490620](https://snowtrace.io/address/0x6ab707Aca953eDAeFBc4fD23bA73294241490620) |
| aAVAXb on Avalanche           | [0x6C6f910A79639dcC94b4feEF59Ff507c2E843929](https://snowtrace.io/address/0x6C6f910A79639dcC94b4feEF59Ff507c2E843929) |
| WAVAX on Avalanche (reward)   | [0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7](https://snowtrace.io/address/0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7) |
| WBTC on Avalanche             | [0x50b7545627a5162F82A992c33b87aDc75187B218](https://snowtrace.io/address/0x50b7545627a5162F82A992c33b87aDc75187B218) |
| WETH on Avalanche             | [0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB](https://snowtrace.io/address/0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB) |
| USDt on Avalanche             | [0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7](https://snowtrace.io/address/0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7) |
| aBNBb on BSC                  | [0xBb1Aa6e59E5163D8722a122cd66EBA614b59df0d](https://bscscan.com/address/0xBb1Aa6e59E5163D8722a122cd66EBA614b59df0d) |
| BUSD on BSC                   | [0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56](https://bscscan.com/address/0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56) |
| CAKE on BSC (reward)          | [0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82](https://bscscan.com/address/0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82) |
| LP USDT-USDC on BSC           | [0xEc6557348085Aa57C72514D67070dC863C0a5A8c](https://bscscan.com/address/0xEc6557348085Aa57C72514D67070dC863C0a5A8c) |
| LP USDT-BUSD on BSC           | [0x7EFaEf62fDdCCa950418312c6C91Aef321375A00](https://bscscan.com/address/0x7EFaEf62fDdCCa950418312c6C91Aef321375A00) |
| LP USDC-BUSD on BSC           | [0x2354ef4DF11afacb85a5C7f98B624072ECcddbB1](https://bscscan.com/address/0x2354ef4DF11afacb85a5C7f98B624072ECcddbB1) |
| USDC on BSC                   | [0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d](https://bscscan.com/address/0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d) |
| WBNB on BSC                   | [0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c](https://bscscan.com/address/0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c) |
| MATIC on Ethereum             | [0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0](https://polygonscan.com/address/0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0) |
| stETH on Ethereum             | [0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84](https://polygonscan.com/address/0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84) |
| stMATIC on Ethereum           | [0x9ee91F9f426fA633d227f7a9b000E28b9dfd8599](https://polygonscan.com/address/0x9ee91F9f426fA633d227f7a9b000E28b9dfd8599) |
| stDOT on Moonbeam             | [0xFA36Fe1dA08C89eC72Ea1F0143a35bFd5DAea108](https://moonscan.io/token/0xFA36Fe1dA08C89eC72Ea1F0143a35bFd5DAea108) |
| xcDOT on Moonbeam             | [0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080](https://moonscan.io/token/0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080) |
| aPolWMATIC on Polygon         | [0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97](https://polygonscan.com/address/0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97) |
| WMATIC on Polygon             | [0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270](https://polygonscan.com/address/0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270) |


### Auxiliary Contracts

#### Price Oracle

| Network     | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Aurora      | [0xf705ceB44C1330766185459afaF9aA41A3288ca2](https://aurorascan.dev/address/0xf705ceb44c1330766185459afaf9aa41a3288ca2) | [0x2f8cC3eaF60D8B136E6266db6BAae9b8C286b38A](https://testnet.aurorascan.dev/address/0x2f8cC3eaF60D8B136E6266db6BAae9b8C286b38A)
| Avalanche   | [0xb9b31A45bEe57cF30b68a49899021FfCF1930b68](https://snowtrace.io/address/0xb9b31A45bEe57cF30b68a49899021FfCF1930b68) | [0xF7140458031150894d04d9fA3b2E5305deecD617](https://testnet.snowtrace.io/address/0xF7140458031150894d04d9fA3b2E5305deecD617)
| BSC         |  | [0x7e78D5CaB721Cc7340C9EF97511f846Dfac4594e](https://testnet.bscscan.com/address/0x7e78d5cab721cc7340c9ef97511f846dfac4594e)
| Ethereum    |  | [0x61BA70b534c1B828c7Df157e5Af6Cb45CD416ADa](https://rinkeby.etherscan.io/address/0x61ba70b534c1b828c7df157e5af6cb45cd416ada)
| Polygon     | [0x2EDd4b5513e0A9C96921D9e1e9234Fe28cB5519C](https://polygonscan.com/address/0x2edd4b5513e0a9c96921d9e1e9234fe28cb5519c) | [0x927189BDb499ACC18bF025BC34e2fc28539B8b20](https://mumbai.polygonscan.com/address/0x927189BDb499ACC18bF025BC34e2fc28539B8b20)

#### Swapper

| Network     | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Aurora      |  | [0xF7140458031150894d04d9fA3b2E5305deecD617](https://testnet.aurorascan.dev/address/0xF7140458031150894d04d9fA3b2E5305deecD617)
| Avalanche   |  | [0x062AC41C6973c5e7C56b387FCF9d89Cfe13cAE14](https://testnet.snowtrace.io/address/0x062AC41C6973c5e7C56b387FCF9d89Cfe13cAE14)
| BSC         |  | [0x079F09010b29E85E79F9e904166df57AE243b41C](https://testnet.bscscan.com/address/0x079F09010b29E85E79F9e904166df57AE243b41C)
| Ethereum    |  | [0x181448cB4B9bE640673696493216276b6743F589](https://rinkeby.etherscan.io/address/0x181448cb4b9be640673696493216276b6743f589)
| Polygon     |  | [0x539446c1f94ac057B1Db27EdF21D899662Fe1022](https://mumbai.polygonscan.com/address/0x539446c1f94ac057B1Db27EdF21D899662Fe1022)

#### XChainAdapter on cBridge

| Network     | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Aurora      |  | [0x2D8d132fe8Ac9F979E40a23caCB42C9c69b6c252](https://testnet.aurorascan.dev/address/0x2D8d132fe8Ac9F979E40a23caCB42C9c69b6c252)
| Avalanche   |  | [0xe96a94AdA89d50A90DA6a1A4BD84d7A0277055e7](https://testnet.snowtrace.io/address/0xe96a94AdA89d50A90DA6a1A4BD84d7A0277055e7)
| BSC         |  | [0xECF8bE649F83737d2952Eb1f3Bb1102ed36F6b1C](https://testnet.bscscan.com/address/0xECF8bE649F83737d2952Eb1f3Bb1102ed36F6b1C)
| Ethereum    |  | [0x1F19bAF99C103b3afC9f9734566f57F7eEE6B47c](https://rinkeby.etherscan.io/address/0x1f19baf99c103b3afc9f9734566f57f7eee6b47c)
| Polygon     |  | [0x82FaC35fFB3eBcEe89FEcE6Cb7b9763dc504Af31](https://mumbai.polygonscan.com/address/0x82FaC35fFB3eBcEe89FEcE6Cb7b9763dc504Af31)

#### XChainAdapter on Multichain

| Network     | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Avalanche   |  | [0x2Cb3455B63a04B84c4161d3E683f2bF574a39340](https://testnet.snowtrace.io/address/0x2Cb3455B63a04B84c4161d3E683f2bF574a39340)
| BSC         |  | [0x8f4C0598A3a72142fEe00DB35f963BD9db62de2D](https://testnet.bscscan.com/address/0x8f4c0598a3a72142fee00db35f963bd9db62de2d)
| Ethereum    |  | [0x9D59b72964A7Fdb4AEa066101663FdFF710DdC05](https://rinkeby.etherscan.io/address/0x9d59b72964a7fdb4aea066101663fdff710ddc05)
| Polygon     |  | [0x09BE4DF001Af1944214A1BF2883E7EbDc79d174a](https://mumbai.polygonscan.com/address/0x09be4df001af1944214a1bf2883e7ebdc79d174a)


### Products

#### L2 Vaults

| Network     | Mainnet                                                                                                               | Testnet                                                                                                               |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| bniL2WNEAR on Aurora          | [0x463511073EdEeb4842EB6A9776e2D06221C42F88](https://aurorascan.dev/address/0x463511073EdEeb4842EB6A9776e2D06221C42F88) | [0x94A2c970dF27Af68C609E2A3115714211Acd4213](https://testnet.aurorascan.dev/address/0x94A2c970dF27Af68C609E2A3115714211Acd4213)
| stiL2stNEAR on Aurora         |  | [0x7ae18664426F6626059424f74B4596E5fc909e6D](https://testnet.aurorascan.dev/address/0x7ae18664426F6626059424f74B4596E5fc909e6D)
| stiStNEAR on Aurora           |  | [0x5A2E621d7d2bDB1b339A500859b019171FBfD009](https://testnet.aurorascan.dev/address/0x5A2E621d7d2bDB1b339A500859b019171FBfD009)
| mwiL2USDT on Avalanche        | [0x4563883E3cE04cd2fE997b726C987422461a5216](https://snowtrace.io/address/0x4563883E3cE04cd2fE997b726C987422461a5216) |
| mwiL2WAVAX on Avalanche       | [0xF070c998d8a642E306cf76aF2DB319b3bD843aE6](https://snowtrace.io/address/0xF070c998d8a642E306cf76aF2DB319b3bD843aE6) |
| mwiL2WBTC on Avalanche        | [0x9e23A237b4a55111dD133A38d48784E8f544309a](https://snowtrace.io/address/0x9e23A237b4a55111dD133A38d48784E8f544309a) |
| mwiL2WETH on Avalanche        | [0xe337e3ba156663592b293480Db22D66761ad45e9](https://snowtrace.io/address/0xe337e3ba156663592b293480Db22D66761ad45e9) |
| stiStAVAX on Avalanche        |  | [0x35C076079E3d280935428ec5764F384e3e2aeab4](https://testnet.snowtrace.io/address/0x35c076079e3d280935428ec5764f384e3e2aeab4)
| lciL2USDCB on BSC             | [0x8083c6a8369D5F386fE75450AD953C1736a004eD](https://bscscan.com/address/0x8083c6a8369D5F386fE75450AD953C1736a004eD) |
| lciL2USDTB on BSC             | [0x66D83e0e7baD685Bd94b2F7F41B973B42fB1E2d8](https://bscscan.com/address/0x66D83e0e7baD685Bd94b2F7F41B973B42fB1E2d8) |
| lciL2USDTC on BSC             | [0x04FEd86Cf6227F315669b9d762b2D75c3A2316d1](https://bscscan.com/address/0x04FEd86Cf6227F315669b9d762b2D75c3A2316d1) |
| stiStBNB on BSC               |  | [0x9D5061c9267531dE92B1e36780bFFE4c1C944852](https://testnet.bscscan.com/address/0x9d5061c9267531de92b1e36780bffe4c1c944852)
| stiStETH on Ethereum          |  | [0x43Af52B9632C81740f79fdc0944827F1ca52c064](https://rinkeby.etherscan.io/address/0x43af52b9632c81740f79fdc0944827f1ca52c064)
| stiStMATIC on Ethereum        |  | [0xD50460917B22BAc87aB640e429237b908E4BD7f4](https://rinkeby.etherscan.io/address/0xD50460917B22BAc87aB640e429237b908E4BD7f4)
| bniL2WMATIC on Polygon        | [0x52235Cf0D2861414EC8363FBbdAe2D8521B23D79](https://polygonscan.com/address/0x52235Cf0D2861414EC8363FBbdAe2D8521B23D79) |

#### LCI

| Products          | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| LCI on BSC        | [0x8FD52c2156a0475e35E0FEf37Fa396611062c9b6](https://bscscan.com/address/0x8FD52c2156a0475e35E0FEf37Fa396611062c9b6) | [0x69380cc2169046f8A3B2c03D58Fe206475aAe3CB](https://testnet.bscscan.com/address/0x69380cc2169046f8a3b2c03d58fe206475aae3cb)

#### MWI

| Products          | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| MWI on Avalanche  | [0x5aCBd5b82edDae114EC0703c86d163bD0107367c](https://snowtrace.io/address/0x5aCBd5b82edDae114EC0703c86d163bD0107367c) | [0x48Ef64b90c7c04AE5353Bdaab075242D8B325170](https://testnet.snowtrace.io/address/0x48ef64b90c7c04ae5353bdaab075242d8b325170)

#### BNI

| Products                  | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| BNI on Avalanche          | [0x52942c46F355aC354CFdeF72fd96b41eE10D7C72](https://snowtrace.io/address/0x52942c46F355aC354CFdeF72fd96b41eE10D7C72) | [0x25Ce8a40cfe13B890769FD4CC640e16Ce034E73e](https://testnet.snowtrace.io/address/0x25Ce8a40cfe13B890769FD4CC640e16Ce034E73e)
| BNIMinter on Avalanche    | [0xCbAB0d4c9B040e94cA392f0C3c65D136C17ee290](https://snowtrace.io/address/0xCbAB0d4c9B040e94cA392f0C3c65D136C17ee290) | [0x4f8Ebe88aC0978c0696D6f61ca994CA73903ec96](https://testnet.snowtrace.io/address/0x4f8Ebe88aC0978c0696D6f61ca994CA73903ec96)
| BNIVault on Aurora        | [0x72eB6E3f163E8CFD1Ebdd7B2f4ffB60b6e420448](https://aurorascan.dev/address/0x72eB6E3f163E8CFD1Ebdd7B2f4ffB60b6e420448) | [0x25276F97f70c2E3bC907f6B5A955a76248ae9945](https://testnet.aurorascan.dev/address/0x25276f97f70c2e3bc907f6b5a955a76248ae9945)
| BNIVault on Avalanche     | [0xe76367024ca3AEeC875A03BB395f54D7c6A82eb0](https://snowtrace.io/address/0xe76367024ca3AEeC875A03BB395f54D7c6A82eb0) | [0x0cB5F3b91161D870A35b6d2671A73a6A5bB7F847](https://testnet.snowtrace.io/address/0x0cB5F3b91161D870A35b6d2671A73a6A5bB7F847)
| BNIVault on Polygon       | [0xF9258759bADb75a9eAb16933ADd056c9F4E489b6](https://polygonscan.com/address/0xF9258759bADb75a9eAb16933ADd056c9F4E489b6) | [0xE276b8197D61D1b5da0d50E0B6c7B41937da29C3](https://mumbai.polygonscan.com/address/0xe276b8197d61d1b5da0d50e0b6c7b41937da29c3)
| BNIUserAgent on Aurora    |  | [0x1edfd9120254B82441fEfbCf2D4fB9ccbCfa07c0](https://testnet.aurorascan.dev/address/0x1edfd9120254B82441fEfbCf2D4fB9ccbCfa07c0)
| BNIUserAgent on Avalanche |  | [0x86377B4726eC01c8378c2d8fB5BA95E8B866a0bf](https://testnet.snowtrace.io/address/0x86377B4726eC01c8378c2d8fB5BA95E8B866a0bf)
| BNIUserAgent on Polygon   |  | [0x846AB2a040ff470dfb513038e78844014e4686FF](https://mumbai.polygonscan.com/address/0x846ab2a040ff470dfb513038e78844014e4686ff)

#### STI

| Products                  | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| STI on Avalanche          |  | [0x4F7958BaD34D30618C045163fdf740503B1d7770](https://rinkeby.etherscan.io/address/0x4f7958bad34d30618c045163fdf740503b1d7770)
| STIMinter on Avalanche    |  | [0xA9a2e9aeF861b5d43578f517F2103940A5011387](https://rinkeby.etherscan.io/address/0xA9a2e9aeF861b5d43578f517F2103940A5011387)
| STIVault on Aurora        |  | [0x846AB2a040ff470dfb513038e78844014e4686FF](https://testnet.aurorascan.dev/address/0x846AB2a040ff470dfb513038e78844014e4686FF)
| STIVault on Avalanche     |  | [0x1edfd9120254B82441fEfbCf2D4fB9ccbCfa07c0](https://testnet.snowtrace.io/address/0x1edfd9120254B82441fEfbCf2D4fB9ccbCfa07c0)
| STIVault on BSC           |  | [0xdc9638F1664932a67F9632Fd224b9FE06E5F91F6](https://testnet.bscscan.com/address/0xdc9638F1664932a67F9632Fd224b9FE06E5F91F6)
| STIVault on Ethereum      |  | [0xee018FA7839BaCb0064562730A6673A20E430a9d](https://rinkeby.etherscan.io/address/0xee018fa7839bacb0064562730a6673a20e430a9d)
| STIUserAgent on Aurora    |  | [0xbBBe66F9C0aC9B7790296f0BEd27047f377BDC01](https://testnet.aurorascan.dev/address/0xbbbe66f9c0ac9b7790296f0bed27047f377bdc01)
| STIUserAgent on Avalanche |  | [0xb9Af9Fd316e9cF7Bd5FC1561F9dED28Fb9560031](https://testnet.snowtrace.io/address/0xb9Af9Fd316e9cF7Bd5FC1561F9dED28Fb9560031)
| STIUserAgent on BSC       |  | [0x9Ba0B916144fC36595c4A9941464E39d24806b8a](https://testnet.bscscan.com/address/0x9ba0b916144fc36595c4a9941464e39d24806b8a)
| STIUserAgent on Ethereum  |  | [0x2D1d9A1E12626Ba50664faeDf2DD267ef110541c](https://rinkeby.etherscan.io/address/0x2d1d9a1e12626ba50664faedf2dd267ef110541c)
