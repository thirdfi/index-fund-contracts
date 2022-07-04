const { ethers } = require("hardhat");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying AuroraBastionVault ...");
  const vault = await deploy("AuroraBastionVault", {
    from: deployer.address,
  });
  console.log("  AuroraBastionVault contract address: ", vault.address);

  console.log("Now deploying CompoundVaultFactory ...");
  const vaultFactory = await deploy("CompoundVaultFactory", {
    from: deployer.address,
    args: [vault.address],
  });
  console.log("  CompoundVaultFactory contract address: ", vaultFactory.address);

  // Verify the implementation contract
  try {
    await run("verify:verify", {
      address: vault.address,
      contract: "contracts/l2Vaults/compound/AuroraBastionVault.sol:AuroraBastionVault",
    });
  } catch(e) {
  }
  try {
    await run("verify:verify", {
      address: vaultFactory.address,
      constructorArguments: [
        vault.address
      ],
      contract: "contracts/l2Vaults/compound/CompoundVaultFactory.sol:CompoundVaultFactory",
    });
  } catch(e) {
  }

};
module.exports.tags = ["auroraMainnet_l2_BastionFactory"];
