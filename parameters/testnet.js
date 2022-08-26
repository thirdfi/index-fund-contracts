const { ethers } = require("hardhat");
const AddressZero = ethers.constants.AddressZero;

module.exports = {
  common: {
    admin: "0x3f68A3c1023d736D8Be867CA49Cb18c543373B99",
    treasury: "0x59E83877bD248cBFe392dbB5A8a29959bcb48592",
    nativeAsset: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
  },

  auroraTestnet: {
    chainId: 1313161555,
    biconomy: AddressZero,
    Bastion: {
      cNEAR: "0x8C14ea853321028a7bb5E4FB0d0147F183d3B677",
      cstNEAR1: "0xB76108eb764b4427505c4bb020A37D95b3ef5AFE",
    },
    Swap: {
      router: "0x26ec2aFBDFdFB972F106100A3deaE5887353d9B9", // Trisolaris
      SWAP_BASE_TOKEN: "0x4861825E75ab14553E5aF711EbbE6873d369d146", // WNEAR
      USDT: "0xF9C249974c1Acf96a59e5757Cc9ba7035cE489B1", // "0x8547A073cbc7D4aF48aD061b9D005C06D55337F5",
      WNEAR: "0x4861825E75ab14553E5aF711EbbE6873d369d146",
    },
    Token: {
      stNEAR: "0x2137df2e54abd6bF1c1a8c1739f2EA6A8C15F144",
    },
    cBridge: {
      messageBus: AddressZero,
    },
  },

  avaxTestnet: {
    chainId: 43113,
    biconomy: "0x6271Ca63D30507f2Dcbf99B52787032506D75BBF",
    Aave3: {
      aAvaWBTC: "0x07B2C0b69c70e89C94A20A555Ab376E5a6181eE6",
      aAvaWETH: "0x618922b15a1a92652818473741531eE255f68741",
      aAvaWAVAX: "0xC50E6F9E8e6CAd53c42ddCB7A42d616d7420fd3e",
      aAvaUSDT: "0x3a7e85a86F952CB61485e2D20BDDb6e15204744f",
    },
    Swap: {
      router: "0xd7f655E3376cE2D7A2b08fF01Eb3B1023191A901", // TraderJoe
      SWAP_BASE_TOKEN: "0xd00ae08403B9bbb9124bB305C09058E32C39A48c", // WAVAX
      USDT: "0x78ae2880bd1672b49a33cF796CF53FE6db0aB01D", // "0x78ae2880bd1672b49a33cF796CF53FE6db0aB01D",
      WAVAX: "0xd00ae08403B9bbb9124bB305C09058E32C39A48c",
    },
    Token: {
      WBTC: "0x50b7545627a5162F82A992c33b87aDc75187B218",
      WETH: "0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB",
      WAVAX: "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7",
      USDt: "0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7",
      aAVAXb: "0xBd97c29aa3E83C523C9714edCA8DB8881841a593",
    },
    cBridge: {
      messageBus: "0xE9533976C590200E32d95C53f06AE12d292cFc47",
    },
  },

  bscTestnet: {
    chainId: 97,
    biconomy: "0x61456BF1715C1415730076BB79ae118E806E74d2",
    PancakeSwap: {
      Farm_USDT_USDC_pid: 48,
      Farm_USDT_BUSD_pid: 7,
      Farm_USDC_BUSD_pid: 20,
    },
    Swap: {
      router: "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3", // PancakeSwap
      SWAP_BASE_TOKEN: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd", // WBNB
    },
    Token: {
      USDT: "0x1F326a8CA5399418a76eA0efa0403Cbb00790C67",
      WBNB: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",
      aBNBb: "0xaB56897fE4e9f0757e02B54C27E81B9ddd6A30AE",
    },
    cBridge: {
      messageBus: "0xAd204986D6cB67A5Bc76a3CB8974823F43Cb9AAA",
    },
  },

  ethRinkeby: {
    chainId: 4,
    biconomy: "0xFD4973FeB2031D4409fB57afEE5dF2051b171104",
    Swap: {
      router: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", // Uniswap v2
      SWAP_BASE_TOKEN: "0xc778417E063141139Fce010982780140Aa0cD5Ab", // WETH
    },
    Token: {
      MATIC: "0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0",
      stETH: "0xF4242f9d78DB7218Ad72Ee3aE14469DBDE8731eD",
      stMATIC: "0x9ee91F9f426fA633d227f7a9b000E28b9dfd8599",
      USDT: "0x21e48034753E490ff04f2f75f7CAEdF081B320d5",
      WETH: "0xc778417E063141139Fce010982780140Aa0cD5Ab",
    },
    cBridge: {
      messageBus: AddressZero,
    },
  },

  maticMumbai: {
    chainId: 80001,
    biconomy: "0x9399BB24DBB5C4b782C70c2969F58716Ebbd6a3b",
    Aave3: {
      aPolWMATIC: "0x89a6AE840b3F8f489418933A220315eeA36d11fF",
    },
    Swap: {
      router: "0x8954AfA98594b838bda56FE4C12a09D7739D179b", // QuickSwap
      SWAP_BASE_TOKEN: "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889", // WMATIC
      USDT: "0x7e4C234B1d634DB790592d1550816b19E862F744", // "0x3813e82e6f7098b9583FC0F33a962D02018B6803",
      WMATIC: "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889",
    },
    cBridge: {
      messageBus: "0x7d43AABC515C356145049227CeE54B608342c0ad",
    },
  },

};
