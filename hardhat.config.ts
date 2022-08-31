import type { HardhatUserConfig, HttpNetworkUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import '@nomiclabs/hardhat-ethers';
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-gas-reporter";
import 'hardhat-contract-sizer';
import 'solidity-coverage';
import dotenv from "dotenv";
// import yargs from "yargs";

dotenv.config();

// const argv = yargs
//   .option("network", {
//     type: "string",
//     default: "hardhat",
//   })
//   .help(false)
//   .version(false).argv;

// type ArgKey = keyof typeof argv;
// const networkKey = 'network' as ArgKey;
// const network = argv[networkKey];
const chainId = process.env.CHAIN_ID ? parseInt(process.env.CHAIN_ID) : 1;

const sharedNetworkConfig: HttpNetworkUserConfig = {};
if (process.env.PRIVATE_KEY) {
  sharedNetworkConfig.accounts = [process.env.PRIVATE_KEY];
} else {
  sharedNetworkConfig.accounts = {
    mnemonic: process.env.MNEMONIC || "",
  };
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [{
      version: "0.8.9",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }]
  },
  networks: {
    hardhat: {
      chainId: chainId,
    },
    auroraMainnet: {
      ...sharedNetworkConfig,
      url: `https://mainnet.aurora.dev`,
    },
    auroraTestnet: {
      ...sharedNetworkConfig,
      url: `https://testnet.aurora.dev`,
    },
    avaxMainnet: {
      ...sharedNetworkConfig,
      url: `https://api.avax.network/ext/bc/C/rpc`,
    },
    avaxTestnet: {
      ...sharedNetworkConfig,
      url: `https://api.avax-test.network/ext/bc/C/rpc`,
    },
    bscMainnet: {
      ...sharedNetworkConfig,
      url: `https://bsc-dataseed.binance.org`,
    },
    bscTestnet: {
      ...sharedNetworkConfig,
      url: `https://data-seed-prebsc-2-s1.binance.org:8545`,
    },
    ethMainnet: {
      ...sharedNetworkConfig,
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    ethRinkeby: {
      ...sharedNetworkConfig,
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    ftmTestnet: {
      ...sharedNetworkConfig,
      url: `https://rpc.testnet.fantom.network`,
    },
    maticMainnet: {
      ...sharedNetworkConfig,
      url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_POLYGON_MAINNET_API_KEY}`,
      // url: `https://rpc-mainnet.maticvigil.com`, // ethers.provider.getStorageAt is failed with this url
    },
    maticMumbai: {
      ...sharedNetworkConfig,
      url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.ALCHEMY_POLYGON_MUMBAI_API_KEY}`,
    },
  },
  etherscan: {
    apiKey: {
      // Refer to @nomiclabs/hardhat-etherscan/src/ChainConfig.ts
      aurora: process.env.AURORASCAN_API_KEY || "",
      auroraTestnet: process.env.AURORASCAN_API_KEY || "",
      avalanche: process.env.AVAXSCAN_API_KEY || "",
      avalancheFujiTestnet: process.env.AVAXSCAN_API_KEY || "",
      bsc: process.env.BSCSCAN_API_KEY || "",
      bscTestnet: process.env.BSCSCAN_API_KEY || "",
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      rinkeby: process.env.ETHERSCAN_API_KEY || "",
      opera: process.env.FANTOMSCAN_API_KEY || "",
      ftmTestnet: process.env.FANTOMSCAN_API_KEY || "",
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || "",
    }
  },
  gasReporter: {
    enabled: true
  },
  mocha: {
    timeout: 120000
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: false,
    strict: true,
  }
};
export default config