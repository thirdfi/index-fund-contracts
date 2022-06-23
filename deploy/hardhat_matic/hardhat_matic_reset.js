const { network } = require("hardhat");
require("dotenv").config();

const mainnetUrl = `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_POLYGON_MAINNET_API_KEY}`;
const mainnetBlockNumber = 29697590;

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
module.exports.tags = ["hardhat_matic_reset"];
