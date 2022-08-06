const { ethers } = require("hardhat");
const { common } = require("../../parameters/testnet");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  const priceOracleProxy = await ethers.getContract("EthPriceOracleTest_Proxy");
  const stETHVaultProxy = await ethers.getContract("EthStETHVaultTest_Proxy");
  const stMATICVaultProxy = await ethers.getContract("EthStMATICVaultTest_Proxy");

  console.log("Now deploying EthSTIStrategyTest...");
  const proxy = await deploy("EthSTIStrategyTest", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize1",
          args: [
            common.admin,
            priceOracleProxy.address,
            stETHVaultProxy.address, stMATICVaultProxy.address,
          ],
        },
      },
    },
  });
  console.log("  EthSTIStrategyTest_Proxy contract address: ", proxy.address);

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/sti/strategy/EthSTIStrategyTest.sol:EthSTIStrategyTest",
    });
  } catch (e) {
  }
};
module.exports.tags = ["ethRinkeby_sti_STIStrategy"];
