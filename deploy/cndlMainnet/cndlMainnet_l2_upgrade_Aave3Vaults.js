const { ethers } = require("hardhat");
const UpgradeableBeacon_ABI = require("@openzeppelin/contracts/build/contracts/UpgradeableBeacon.json").abi;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying MaticAave3Vault ...");
  const vault = await deploy("MaticAave3Vault", {
    from: deployer.address,
  });
  console.log("  MaticAave3Vault contract address: ", vault.address);

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
      contract: "contracts/l2Vaults/aave3/MaticAave3Vault.sol:MaticAave3Vault",
    });
  } catch(e) {
  }

};
module.exports.tags = ["cndlMainnet_l2_upgrade_Aave3Vaults"];
