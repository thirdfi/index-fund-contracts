const { ethers } = require("hardhat");
const AddressZero = ethers.constants.AddressZero;

module.exports = {
  common: {
    admin: "0x3f68A3c1023d736D8Be867CA49Cb18c543373B99",
    treasury: "0x3f68A3c1023d736D8Be867CA49Cb18c543373B99",
    nativeAsset: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
  },

  auroraMainnet: {
    chainId: 1313161554,
    Securo: {
      mchainAdapter: AddressZero,
      cbridgeAdapter: "",
      bniUserAgent: "",
      stiUserAgent: "",
    },
    biconomy: AddressZero,
    Bastion: {
      cNEAR: "0x8C14ea853321028a7bb5E4FB0d0147F183d3B677",
      cstNEAR1: "0xB76108eb764b4427505c4bb020A37D95b3ef5AFE",
    },
    Swap: {
      router: "0x2CB45Edb4517d5947aFdE3BEAbF95A582506858B", // Trisolaris
      SWAP_BASE_TOKEN: "0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d", // WNEAR
      USDT: "0x4988a896b1227218e4A686fdE5EabdcAbd91571f",
      WNEAR: "0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d",
    },
    Token: {
      stNEAR: "0x07F9F7f963C5cD2BBFFd30CcfB964Be114332E30",
    },
    cBridge: {
      messageBus: "0xc1a2D967DfAa6A10f3461bc21864C23C1DD51EeA",
    },
  },

  avaxMainnet: {
    chainId: 43114,
    Securo: {
      mchainAdapter: "",
      cbridgeAdapter: "",
      bniUserAgent: "",
      stiUserAgent: "",
    },
    biconomy: "0x64CD353384109423a966dCd3Aa30D884C9b2E057",
    Aave3: {
      aAvaWBTC: "0x078f358208685046a11C85e8ad32895DED33A249",
      aAvaWETH: "0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8",
      aAvaWAVAX: "0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97",
      aAvaUSDT: "0x6ab707Aca953eDAeFBc4fD23bA73294241490620",
    },
    Swap: {
      router: "0x60aE616a2155Ee3d9A68541Ba4544862310933d4", // TraderJoe
      SWAP_BASE_TOKEN: "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7", // WAVAX
      USDT: "0xc7198437980c041c805A1EDcbA50c1Ce5db95118",
      WAVAX: "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7",
    },
    Token: {
      WBTC: "0x50b7545627a5162F82A992c33b87aDc75187B218",
      WETH: "0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB",
      WAVAX: "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7",
      USDt: "0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7",
      aAVAXb: "0x6C6f910A79639dcC94b4feEF59Ff507c2E843929",
    },
    cBridge: {
      messageBus: "0x5a926eeeAFc4D217ADd17e9641e8cE23Cd01Ad57",
    },
  },

  bscMainnet: {
    chainId: 56,
    Securo: {
      mchainAdapter: "",
      cbridgeAdapter: "",
      bniUserAgent: AddressZero,
      stiUserAgent: "",
    },
    biconomy: "0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8",
    PancakeSwap: {
      Farm_USDT_USDC_pid: 48,
      Farm_USDT_BUSD_pid: 7,
      Farm_USDC_BUSD_pid: 20,
    },
    Swap: {
      router: "0x10ED43C718714eb63d5aA57B78B54704E256024E", // PancakeSwap
      SWAP_BASE_TOKEN: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", // WBNB
    },
    Token: {
      USDT: "0x55d398326f99059fF775485246999027B3197955",
      WBNB: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
      aBNBb: "0xBb1Aa6e59E5163D8722a122cd66EBA614b59df0d",
    },
    cBridge: {
      messageBus: "0x95714818fdd7a5454F73Da9c777B3ee6EbAEEa6B",
    },
  },

  ethMainnet: {
    chainId: 1,
    Securo: {
      mchainAdapter: "",
      cbridgeAdapter: "",
      bniUserAgent: AddressZero,
      stiUserAgent: "",
    },
    biconomy: "0x84a0856b038eaAd1cC7E297cF34A7e72685A8693",
    Swap: {
      router: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", // Uniswap v2
      SWAP_BASE_TOKEN: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // WETH
    },
    Token: {
      MATIC: "0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0",
      stETH: "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84",
      stMATIC: "0x9ee91F9f426fA633d227f7a9b000E28b9dfd8599",
      USDT: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
      WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    },
    cBridge: {
      messageBus: "0x4066D196A423b2b3B8B054f4F40efB47a74E200C",
    },
  },

  maticMainnet: {
    chainId: 137,
    Securo: {
      mchainAdapter: "",
      cbridgeAdapter: "",
      bniUserAgent: "",
      stiUserAgent: AddressZero,
    },
    biconomy: "0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8",
    Aave3: {
      aPolWMATIC: "0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97",
    },
    Swap: {
      router: "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff", // QuickSwap
      SWAP_BASE_TOKEN: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", // WMATIC
      USDT: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
      WMATIC: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    },
    cBridge: {
      messageBus: "0xaFDb9C40C7144022811F034EE07Ce2E110093fe6",
    },
  },

};
