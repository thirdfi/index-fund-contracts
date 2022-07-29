require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require('@nomiclabs/hardhat-ethers');
require("hardhat-deploy");
require("hardhat-deploy-ethers");
require("hardhat-gas-reporter");
require('hardhat-contract-sizer');
require('solidity-coverage');
require("dotenv").config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

module.exports = {
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
      // chainId: chainId,
    },
    auroraMainnet: {
      url: `https://mainnet.aurora.dev`,
      accounts: [process.env.PRIVATE_KEY]
    },
    auroraTestnet: {
      url: `https://testnet.aurora.dev`,
      accounts: [process.env.PRIVATE_KEY]
    },
    avaxMainnet: {
      url: `https://api.avax.network/ext/bc/C/rpc`,
      accounts: [process.env.PRIVATE_KEY]
    },
    avaxTestnet: {
      url: `https://api.avax-test.network/ext/bc/C/rpc`,
      accounts: [process.env.PRIVATE_KEY]
    },
    bscMainnet: {
      url: `https://bsc-dataseed.binance.org`,
      accounts: [process.env.PRIVATE_KEY]
    },
    bscTestnet: {
      url: `https://data-seed-prebsc-2-s1.binance.org:8545`,
      accounts: [process.env.PRIVATE_KEY]
    },
    ethMainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY]
    },
    ethRinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY]
    },
    maticMainnet: {
      url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_POLYGON_MAINNET_API_KEY}`,
      // url: `https://rpc-mainnet.maticvigil.com`, // ethers.provider.getStorageAt is failed with this url
      accounts: [process.env.PRIVATE_KEY]
    },
    maticMumbai: {
      url: `https://rpc-mumbai.maticvigil.com`,
      accounts: [process.env.PRIVATE_KEY]
    },
  },
  etherscan: {
    apiKey: {
      auroraMainnet: process.env.AURORASCAN_API_KEY,
      auroraTestnet: process.env.AURORASCAN_API_KEY,
      avaxMainnet: process.env.AVAXSCAN_API_KEY,
      avaxTestnet: process.env.AVAXSCAN_API_KEY,
      bscMainnet: process.env.BSCSCAN_API_KEY,
      bscTestnet: process.env.BSCSCAN_API_KEY,
      ethMainnet: process.env.ETHERSCAN_API_KEY,
      ethRinkeby: process.env.ETHERSCAN_API_KEY,
      maticMainnet: process.env.POLYGONSCAN_API_KEY,
      maticMumbai: process.env.POLYGONSCAN_API_KEY,
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
