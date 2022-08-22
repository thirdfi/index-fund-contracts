const { network } = require("hardhat");
require("dotenv").config();

const mainnetUrl = `https://bsc-mainnet.nodereal.io/v1/${process.env.NODEREAL_API_KEY}`;
const mainnetBlockNumber = 20638900;

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
module.exports.tags = ["hardhat_bsc_reset"];
