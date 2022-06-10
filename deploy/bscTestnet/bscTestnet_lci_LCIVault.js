const { ethers } = require("hardhat");
const { common, bscTestnet: network_ } = require("../../parameters");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  const strategyProxy = await ethers.getContract("LCIStrategyTest_Proxy");
  const LCIStrategy = await ethers.getContractFactory("LCIStrategyTest");
  const strategy = LCIStrategy.attach(strategyProxy.address);

  console.log("Now deploying LCIVault...");
  const proxy = await deploy("LCIVaultTest", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            common.treasury, common.admin,
            network_.biconomy, strategy.address,
          ],
        },
      },
    },
  });
  console.log("  LCIVault_Proxy contract address: ", proxy.address);

  const tx = await strategy.setVault(proxy.address);
  await tx.wait();

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/lci/LCIVaultTest.sol:LCIVaultTest",
    });
  } catch (e) {
  }
};
module.exports.tags = ["bscTestnet_lci_LCIVault"];
