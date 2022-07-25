const { ethers } = require("hardhat");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying StVaultNFT ...");
  const vault = await deploy("StVaultNFT", {
    from: deployer.address,
  });
  console.log("  StVaultNFT contract address: ", vault.address);

  console.log("Now deploying StVaultNFTFactory ...");
  const vaultFactory = await deploy("StVaultNFTFactory", {
    from: deployer.address,
    args: [vault.address],
  });
  console.log("  StVaultNFTFactory contract address: ", vaultFactory.address);

  // Verify the implementation contract
  try {
    await run("verify:verify", {
      address: vault.address,
      contract: "contracts/stVaults/StVaultNFT.sol:StVaultNFT",
    });
  } catch(e) {
  }
  try {
    await run("verify:verify", {
      address: vaultFactory.address,
      constructorArguments: [
        vault.address
      ],
      contract: "contracts/stVaults/StVaultNFTFactory.sol:StVaultNFTFactory",
    });
  } catch(e) {
  }

};
module.exports.tags = ["common_sti_StVaultNFTFactory"];
