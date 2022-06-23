const { network } = require("hardhat");
require("dotenv").config();

const mainnetUrl = `https://api.avax.network/ext/bc/C/rpc`;
const mainnetBlockNumber = 16014700;

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
module.exports.tags = ["hardhat_avax_reset"];
