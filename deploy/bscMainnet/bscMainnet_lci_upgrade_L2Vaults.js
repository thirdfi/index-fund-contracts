const { ethers } = require("hardhat");
const { bscMainnet: network_ } = require("../../parameters");
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying PckFarm2Vault ...");
  const bscVault = await deploy("PckFarm2Vault", {
    from: deployer.address,
  });
  console.log("  PckFarm2Vault contract address: ", bscVault.address);

  const bscVaultFactory = await ethers.getContract("PckFarm2VaultFactory");
  let tx = await bscVaultFactory.updateLogic(bscVault.address);
  await tx.wait();

  const PckFarm2Vault = await ethers.getContractFactory("PckFarm2Vault");
  try {
    let l2VaultAddr = await bscVaultFactory.getVaultByPid(network_.PancakeSwap.Farm_USDT_USDC_pid);
    if (l2VaultAddr !== AddressZero) {
      const l2Vault = PckFarm2Vault.attach(l2VaultAddr);
      tx = await l2Vault.resetLpRewardApr();
      await tx.wait();
    }
  } catch(e) {
  }
  try {
    let l2VaultAddr = await bscVaultFactory.getVaultByPid(network_.PancakeSwap.Farm_USDT_BUSD_pid);
    if (l2VaultAddr !== AddressZero) {
      const l2Vault = PckFarm2Vault.attach(l2VaultAddr);
      tx = await l2Vault.resetLpRewardApr();
      await tx.wait();
    }
  } catch(e) {
  }
  try {
    l2VaultAddr = await bscVaultFactory.getVaultByPid(network_.PancakeSwap.Farm_USDC_BUSD_pid);
    if (l2VaultAddr !== AddressZero) {
      const l2Vault = PckFarm2Vault.attach(l2VaultAddr);
      tx = await l2Vault.resetLpRewardApr();
      await tx.wait();
    }
  } catch(e) {
  }

  // Verify the implementation contract
  try {
    await run("verify:verify", {
      address: bscVault.address,
      contract: "contracts/lci/deps/PckFarm2Vault.sol:PckFarm2Vault",
    });
  } catch(e) {
  }

};
module.exports.tags = ["bscMainnet_lci_upgrade_L2Vaults"];
