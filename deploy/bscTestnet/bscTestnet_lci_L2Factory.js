const { ethers } = require("hardhat");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying PckFarm2Vault ...");
  const bscVault = await deploy("BscVaultTest", {
    from: deployer.address,
  });
  console.log("  PckFarm2Vault contract address: ", bscVault.address);

  console.log("Now deploying PckFarm2VaultFactory ...");
  const bscVaultFactory = await deploy("PckFarm2VaultFactory", {
    from: deployer.address,
    args: [bscVault.address],
  });
  console.log("  PckFarm2VaultFactory contract address: ", bscVaultFactory.address);

  // Verify the implementation contract
  try {
    await run("verify:verify", {
      address: bscVault.address,
      contract: "contracts/lci/deps/VaultTest.sol:BscVaultTest",
    });
  } catch(e) {
  }
  try {
    await run("verify:verify", {
      address: bscVaultFactory.address,
      constructorArguments: [
        bscVault.address
      ],
      contract: "contracts/lci/deps/PckFarm2VaultFactory.sol:PckFarm2VaultFactory",
    });
  } catch(e) {
  }

};
module.exports.tags = ["bscTestnet_lci_L2Factory"];
