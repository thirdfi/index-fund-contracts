const { ethers } = require("hardhat");
const UpgradeableBeacon_ABI = require("@openzeppelin/contracts/build/contracts/UpgradeableBeacon.json").abi;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying PckFarm2Vault ...");
  const vault = await deploy("PckFarm2Vault", {
    from: deployer.address,
  });
  console.log("  PckFarm2Vault contract address: ", vault.address);

  const vaultFactory = await ethers.getContract("PckFarm2VaultFactory");
  const beacon = new ethers.Contract(await vaultFactory.getBeacon(), UpgradeableBeacon_ABI, deployer);
  if (await beacon.implementation() !== vault.address) {
    let tx = await vaultFactory.updateLogic(vault.address);
    await tx.wait();
  }

  // Verify the implementation contract
  try {
    await run("verify:verify", {
      address: vault.address,
      contract: "contracts/lci/deps/PckFarm2Vault.sol:PckFarm2Vault",
    });
  } catch(e) {
  }

};
module.exports.tags = ["bscMainnet_lci_upgrade_L2Vaults_2"];
