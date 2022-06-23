const { network } = require("hardhat");
require("dotenv").config();

const mainnetUrl = process.env.ALCHEMY_URL_POLYGON_MAINNET;
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
