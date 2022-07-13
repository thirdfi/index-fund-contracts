# Securo Finance

## Products

### Blockchain Network Index (BNI)

Blockchain Network is a tokenised crypto index fund which tracks major Layer 1 Blockchain Network utility tokens, such as AVAX, NEAR, MATIC. An innovative fund to get ahead of the crypto market.

### Low-risk Crypto Index (LCI)

Low-risk Crypto Index is a tokenised crypto index fund which tracks major stablecoins, such as USDC, USDT, DAI. Low risk but stable profit in your portfolio.

### Market Weighted Index (MWI)

Market Weighted Index is a tokenised crypto index fund which tracks major crypto assets, such as Bitcoin, Ethereum, DAI. A secure way to earn profit with bitcoin and top cryptocurrencies.


## Environment

Create files storing private key and API keys.


## Deploy and Verify contracts

### BNI
```text
npx hardhat deploy --network maticMainnet --tags maticMainnet_bni
npx hardhat deploy --network auroraMainnet --tags auroraMainnet_bni
npx hardhat deploy --network avaxMainnet --tags avaxMainnet_bni
```

### LCI
```text
npx hardhat deploy --network bscMainnet --tags bscMainnet_lci
```

### MWI
```text
npx hardhat deploy --network avaxMainnet --tags avaxMainnet_mwi
```


## Contracts

### Tokens

#### USDT

| Network     | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Aurora      | [0x4988a896b1227218e4A686fdE5EabdcAbd91571f](https://aurorascan.dev/address/0x4988a896b1227218e4A686fdE5EabdcAbd91571f) | [0xF9C249974c1Acf96a59e5757Cc9ba7035cE489B1](https://testnet.aurorascan.dev/address/0xf9c249974c1acf96a59e5757cc9ba7035ce489b1)
| Avalanche   | [0xc7198437980c041c805A1EDcbA50c1Ce5db95118](https://snowtrace.io/address/0xc7198437980c041c805A1EDcbA50c1Ce5db95118) | [0x78ae2880bd1672b49a33cF796CF53FE6db0aB01D](https://testnet.snowtrace.io/address/0x78ae2880bd1672b49a33cf796cf53fe6db0ab01d)
| BSC         | [0x55d398326f99059fF775485246999027B3197955](https://bscscan.com/token/0x55d398326f99059fF775485246999027B3197955) | [0x1F326a8CA5399418a76eA0efa0403Cbb00790C67](https://testnet.bscscan.com/address/0x1f326a8ca5399418a76ea0efa0403cbb00790c67)
| Polygon     | [0xc2132D05D31c914a87C6611C10748AEb04B58e8F](https://polygonscan.com/address/0xc2132D05D31c914a87C6611C10748AEb04B58e8F) | [0x7e4C234B1d634DB790592d1550816b19E862F744](https://mumbai.polygonscan.com/address/0x7e4c234b1d634db790592d1550816b19e862f744)

#### Used tokens

| Network     | Mainnet                                                                                                               | Testnet                                                                                                               |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| cNEAR on Aurora               | [0x8C14ea853321028a7bb5E4FB0d0147F183d3B677](https://aurorascan.dev/address/0x8C14ea853321028a7bb5E4FB0d0147F183d3B677) |
| WNEAR on Aurora               | [0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d](https://aurorascan.dev/address/0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d) |
| LP BSTN-WNEAR on Aurora       | [0xBBf3D4281F10E537d5b13CA80bE22362310b2bf9](https://aurorascan.dev/address/0xBBf3D4281F10E537d5b13CA80bE22362310b2bf9) |
| LP WNEAR-USDC on Aurora       | [0x20F8AeFB5697B77E0BB835A8518BE70775cdA1b0](https://aurorascan.dev/address/0x20F8AeFB5697B77E0BB835A8518BE70775cdA1b0) |
| LP WNEAR-USDT on Aurora       | [0x03B666f3488a7992b2385B12dF7f35156d7b29cD](https://aurorascan.dev/address/0x03B666f3488a7992b2385B12dF7f35156d7b29cD) |
| aAvaWAVAX on Avalanche        | [0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97](https://snowtrace.io/address/0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97) |
| aAvaWBTC on Avalanche         | [0x078f358208685046a11C85e8ad32895DED33A249](https://snowtrace.io/address/0x078f358208685046a11C85e8ad32895DED33A249) |
| aAvaWETH on Avalanche         | [0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8](https://snowtrace.io/address/0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8) |
| aAvaUSDT on Avalanche         | [0x6ab707Aca953eDAeFBc4fD23bA73294241490620](https://snowtrace.io/address/0x6ab707Aca953eDAeFBc4fD23bA73294241490620) |
| WAVAX on Avalanche (reward)   | [0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7](https://snowtrace.io/address/0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7) |
| WBTC on Avalanche             | [0x50b7545627a5162F82A992c33b87aDc75187B218](https://snowtrace.io/address/0x50b7545627a5162F82A992c33b87aDc75187B218) |
| WETH on Avalanche             | [0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB](https://snowtrace.io/address/0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB) |
| USDt on Avalanche             | [0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7](https://snowtrace.io/address/0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7) |
| BUSD on BSC                   | [0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56](https://bscscan.com/address/0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56) |
| CAKE on BSC (reward)          | [0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82](https://bscscan.com/address/0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82) |
| LP USDT-USDC on BSC           | [0xEc6557348085Aa57C72514D67070dC863C0a5A8c](https://bscscan.com/address/0xEc6557348085Aa57C72514D67070dC863C0a5A8c) |
| LP USDT-BUSD on BSC           | [0x7EFaEf62fDdCCa950418312c6C91Aef321375A00](https://bscscan.com/address/0x7EFaEf62fDdCCa950418312c6C91Aef321375A00) |
| LP USDC-BUSD on BSC           | [0x2354ef4DF11afacb85a5C7f98B624072ECcddbB1](https://bscscan.com/address/0x2354ef4DF11afacb85a5C7f98B624072ECcddbB1) |
| USDC on BSC                   | [0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d](https://bscscan.com/address/0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d) |
| WBNB on BSC                   | [0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c](https://bscscan.com/address/0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c) |
| aPolWMATIC on Polygon         | [0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97](https://polygonscan.com/address/0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97) |
| WMATIC on Polygon             | [0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270](https://polygonscan.com/address/0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270) |

### Price Oracle

| Network     | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Aurora      | [0xf705ceB44C1330766185459afaF9aA41A3288ca2](https://aurorascan.dev/address/0xf705ceb44c1330766185459afaf9aa41a3288ca2) | [0x147abEE959A578F2ae5F9bC996dcf6259EBd3a89](https://testnet.aurorascan.dev/address/0x147abEE959A578F2ae5F9bC996dcf6259EBd3a89)
| Avalanche   | [0xb9b31A45bEe57cF30b68a49899021FfCF1930b68](https://snowtrace.io/address/0xb9b31A45bEe57cF30b68a49899021FfCF1930b68) | [0x9C0dd87c001eE4A864b9a394Ea722a4382424005](https://testnet.snowtrace.io/address/0x9C0dd87c001eE4A864b9a394Ea722a4382424005)
| Polygon     | [0x2EDd4b5513e0A9C96921D9e1e9234Fe28cB5519C](https://polygonscan.com/address/0x2edd4b5513e0a9c96921d9e1e9234fe28cb5519c) | [0x6809aadCc6b54926c8bAB1DF52CB85b833dcFb33](https://mumbai.polygonscan.com/address/0x6809aadCc6b54926c8bAB1DF52CB85b833dcFb33)


### Products

#### Aurora Products

| Products    | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| BNIVault    | [0x72eB6E3f163E8CFD1Ebdd7B2f4ffB60b6e420448](https://aurorascan.dev/address/0x72eB6E3f163E8CFD1Ebdd7B2f4ffB60b6e420448) | [0x25276F97f70c2E3bC907f6B5A955a76248ae9945](https://testnet.aurorascan.dev/address/0x25276f97f70c2e3bc907f6b5a955a76248ae9945)

#### Avalanche Products

| Products    | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| MWI         | [0x5aCBd5b82edDae114EC0703c86d163bD0107367c](https://snowtrace.io/address/0x5aCBd5b82edDae114EC0703c86d163bD0107367c) | [0x48Ef64b90c7c04AE5353Bdaab075242D8B325170](https://testnet.snowtrace.io/address/0x48ef64b90c7c04ae5353bdaab075242d8b325170)
| BNI         | [0x52942c46F355aC354CFdeF72fd96b41eE10D7C72](https://snowtrace.io/address/0x52942c46F355aC354CFdeF72fd96b41eE10D7C72) | [0x25Ce8a40cfe13B890769FD4CC640e16Ce034E73e](https://testnet.snowtrace.io/address/0x25Ce8a40cfe13B890769FD4CC640e16Ce034E73e)
| BNIMinter   | [0xCbAB0d4c9B040e94cA392f0C3c65D136C17ee290](https://snowtrace.io/address/0xCbAB0d4c9B040e94cA392f0C3c65D136C17ee290) | [0x4f8Ebe88aC0978c0696D6f61ca994CA73903ec96](https://testnet.snowtrace.io/address/0x4f8Ebe88aC0978c0696D6f61ca994CA73903ec96)
| BNIVault    | [0xe76367024ca3AEeC875A03BB395f54D7c6A82eb0](https://snowtrace.io/address/0xe76367024ca3AEeC875A03BB395f54D7c6A82eb0) | [0x0cB5F3b91161D870A35b6d2671A73a6A5bB7F847](https://testnet.snowtrace.io/address/0x0cB5F3b91161D870A35b6d2671A73a6A5bB7F847)

#### BSC Products

| Products    | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| LCI         | [0x8FD52c2156a0475e35E0FEf37Fa396611062c9b6](https://bscscan.com/address/0x8FD52c2156a0475e35E0FEf37Fa396611062c9b6) | [0x69380cc2169046f8A3B2c03D58Fe206475aAe3CB](https://testnet.bscscan.com/address/0x69380cc2169046f8a3b2c03d58fe206475aae3cb)

#### Polygon Products

| Products    | Mainnet                                                                                                               | Testnet                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| BNIVault    | [0xF9258759bADb75a9eAb16933ADd056c9F4E489b6](https://polygonscan.com/address/0xF9258759bADb75a9eAb16933ADd056c9F4E489b6) | [0xE276b8197D61D1b5da0d50E0B6c7B41937da29C3](https://mumbai.polygonscan.com/address/0xe276b8197d61d1b5da0d50e0b6c7b41937da29c3)
