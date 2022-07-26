const { network } = require("hardhat");
require("dotenv").config();

const mainnetUrl = 'https://mainnet.aurora.dev';
const mainnetBlockNumber = 70702200;

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
module.exports.tags = ["hardhat_aurora_reset"];
