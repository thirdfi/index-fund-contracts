const { ethers } = require("hardhat");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying MaticAave3Vault ...");
  const aave3Vault = await deploy("MaticAave3Vault", {
    from: deployer.address,
  });
  console.log("  MaticAave3Vault contract address: ", aave3Vault.address);

  console.log("Now deploying Aave3VaultFactory ...");
  const avaxVaultFactory = await deploy("Aave3VaultFactory", {
    from: deployer.address,
    args: [aave3Vault.address],
  });
  console.log("  Aave3VaultFactory contract address: ", avaxVaultFactory.address);

  // Verify the implementation contract
  try {
    await run("verify:verify", {
      address: aave3Vault.address,
      contract: "contracts/l2Vaults/aave3/MaticAave3Vault.sol:MaticAave3Vault",
    });
  } catch(e) {
  }
  try {
    await run("verify:verify", {
      address: avaxVaultFactory.address,
      constructorArguments: [
        aave3Vault.address
      ],
      contract: "contracts/mwi/deps/Aave3VaultFactory.sol:Aave3VaultFactory",
    });
  } catch(e) {
  }

};
module.exports.tags = ["cndlMainnet_l2_Aave3Factory"];
