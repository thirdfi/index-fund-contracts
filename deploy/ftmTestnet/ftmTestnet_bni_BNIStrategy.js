const { ethers } = require("hardhat");
const { common, ftmTestnet: network_ } = require("../../parameters/testnet");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  const priceOracleProxy = await ethers.getContract("FtmPriceOracleTest_Proxy");

  console.log("Now deploying BNIStrategy...");
  const proxy = await deploy("BNIStrategyTest", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            common.treasury, common.admin,
            priceOracleProxy.address,
            network_.Swap.router, network_.Swap.SWAP_BASE_TOKEN,
            network_.Token.USDT, network_.Token.WFTM
          ],
        },
      },
    },
  });
  console.log("  BNIStrategy_Proxy contract address: ", proxy.address);

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/bni/strategy/BNIStrategyTest.sol:BNIStrategyTest",
    });
  } catch (e) {
  }
};
module.exports.tags = ["ftmTestnet_bni_BNIStrategy"];