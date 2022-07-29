const { network } = require("hardhat");
require("dotenv").config();

const mainnetUrl = `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_ETH_MAINNET_API_KEY}`;
const mainnetBlockNumber = 15236800;

module.exports = async () => {
  await network.provider.request({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          jsonRpcUrl: mainnetUrl,
          blockNumber: mainnetBlockNumber,
        },
      },
    ],
  });
};
module.exports.tags = ["hardhat_eth_reset"];
