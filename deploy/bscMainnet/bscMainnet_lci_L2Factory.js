const { ethers } = require("hardhat");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying BscVault ...");
  const bscVault = await deploy("BscVault", {
    from: deployer.address,
  });
  console.log("  BscVault contract address: ", bscVault.address);

  console.log("Now deploying BscVaultFactory ...");
  const bscVaultFactory = await deploy("BscVaultFactory", {
    from: deployer.address,
  });
  console.log("  BscVaultFactory contract address: ", bscVaultFactory.address);

  // Verify the implementation contract
  try {
    await run("verify:verify", {
      address: bscVault.address,
      contract: "contracts/lci/deps/Vault.sol:BscVault",
    });
  } catch(e) {
  }
  try {
    await run("verify:verify", {
      address: bscVaultFactory.address,
      contract: "contracts/lci/deps/Factory.sol:BscVaultFactory",
    });
  } catch(e) {
  }

};
module.exports.tags = ["bscMainnet_lci_L2Factory"];
