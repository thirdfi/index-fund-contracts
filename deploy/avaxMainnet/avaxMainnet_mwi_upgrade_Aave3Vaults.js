const { ethers } = require("hardhat");
const UpgradeableBeacon_ABI = require("@openzeppelin/contracts/build/contracts/UpgradeableBeacon.json").abi;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying Aave3Vault ...");
  const vault = await deploy("Aave3Vault", {
    from: deployer.address,
  });
  console.log("  Aave3Vault contract address: ", vault.address);

  const vaultFactory = await ethers.getContract("Aave3VaultFactory");
  const beacon = new ethers.Contract(await vaultFactory.getBeacon(), UpgradeableBeacon_ABI, deployer);
  if (await beacon.implementation() !== vault.address) {
    let tx = await vaultFactory.updateLogic(vault.address);
    await tx.wait();
  }

  // Verify the implementation contract
  try {
    await run("verify:verify", {
      address: vault.address,
      contract: "contracts/mwi/deps/Aave3Vault.sol:Aave3Vault",
    });
  } catch(e) {
  }

};
module.exports.tags = ["avaxMainnet_mwi_upgrade_Aave3Vaults"];
