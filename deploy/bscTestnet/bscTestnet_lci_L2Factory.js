const { ethers } = require("hardhat");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying BscVault ...");
  const bscVault = await deploy("BscVaultTest", {
    from: deployer.address,
  });
  console.log("  BscVault contract address: ", bscVault.address);

  console.log("Now deploying BscVaultFactory ...");
  const bscVaultFactory = await deploy("BscVaultFactory", {
    from: deployer.address,
    args: [bscVault.address],
  });
  console.log("  BscVaultFactory contract address: ", bscVaultFactory.address);

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
      contract: "contracts/lci/deps/Factory.sol:BscVaultFactory",
    });
  } catch(e) {
  }

};
module.exports.tags = ["bscTestnet_lci_L2Factory"];
