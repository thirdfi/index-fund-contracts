const { ethers } = require("hardhat");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying AuroraBastionVault ...");
  const vault = await deploy("AuroraBastionVault", {
    from: deployer.address,
  });
  console.log("  AuroraBastionVault contract address: ", vault.address);

  const vaultFactory = await ethers.getContract("CompoundVaultFactory");
  let tx = await vaultFactory.updateLogic(vault.address);
  await tx.wait();

  // Verify the implementation contract
  try {
    await run("verify:verify", {
      address: vault.address,
      contract: "contracts/l2Vaults/compound/AuroraBastionVault.sol:AuroraBastionVault",
    });
  } catch(e) {
  }

};
module.exports.tags = ["auroraMainnet_l2_upgrade_BastionVaults"];
