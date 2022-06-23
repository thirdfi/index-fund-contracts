const { ethers } = require("hardhat");
const { common, bscMainnet: network_ } = require("../../parameters");
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {

  const vaultArtifact = await deployments.getArtifact("PckFarm2Vault");
  const vaultIface = new ethers.utils.Interface(JSON.stringify(vaultArtifact.abi));

  const bscVaultFactory = await ethers.getContract("PckFarm2VaultFactory");

  const dataUSDTUSDC = vaultIface.encodeFunctionData("initialize", [
    "LCI L2 USDT-USDC", "lciL2USDTC",
    network_.PancakeSwap.Farm_USDT_USDC_pid,
    common.treasury, common.admin,
  ]);

  if (await bscVaultFactory.getVaultByPid(network_.PancakeSwap.Farm_USDT_USDC_pid) === AddressZero) {
    console.log("Now deploying USDTUSDCVault ...");
    const tx = await bscVaultFactory.createVault(network_.PancakeSwap.Farm_USDT_USDC_pid, dataUSDTUSDC);
    await tx.wait();
    const USDTUSDCVaultAddr = await bscVaultFactory.getVault((await bscVaultFactory.totalVaults()).sub(1))
    console.log("  USDTUSDCVaultAddr: ", USDTUSDCVaultAddr);
  }

  if (await bscVaultFactory.getVaultByPid(network_.PancakeSwap.Farm_USDT_BUSD_pid) === AddressZero) {
    console.log("Now deploying USDTBUSDVault ...");
    const dataUSDTBUSD= vaultIface.encodeFunctionData("initialize", [
      "LCI L2 USDT-BUSD", "lciL2USDTB",
      network_.PancakeSwap.Farm_USDT_BUSD_pid,
      common.treasury, common.admin,
    ]);

    const tx = await bscVaultFactory.createVault(network_.PancakeSwap.Farm_USDT_BUSD_pid, dataUSDTBUSD);
    await tx.wait();
    const USDTBUSDVaultAddr = await bscVaultFactory.getVault((await bscVaultFactory.totalVaults()).sub(1))
    console.log("  USDTBUSDVaultAddr: ", USDTBUSDVaultAddr);
  }

  if (await bscVaultFactory.getVaultByPid(network_.PancakeSwap.Farm_USDC_BUSD_pid) === AddressZero) {
    console.log("Now deploying USDCBUSDVault ...");
    const dataUSDCBUSD= vaultIface.encodeFunctionData("initialize", [
      "LCI L2 USDC-BUSD", "lciL2USDCB",
      network_.PancakeSwap.Farm_USDC_BUSD_pid,
      common.treasury, common.admin,
    ]);

    const tx = await bscVaultFactory.createVault(network_.PancakeSwap.Farm_USDC_BUSD_pid, dataUSDCBUSD);
    await tx.wait();
    const USDCBUSDVaultAddr = await bscVaultFactory.getVault((await bscVaultFactory.totalVaults()).sub(1))
    console.log("  USDCBUSDVaultAddr: ", USDCBUSDVaultAddr);
  }

  // Verify the contracts
  try {
    await run("verify:verify", {
      address: await bscVaultFactory.getVaultByPid(network_.PancakeSwap.Farm_USDT_USDC_pid),
      constructorArguments: [
        await bscVaultFactory.getBeacon(),
        dataUSDTUSDC
      ],
      contract: "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol:BeaconProxy",
    });
  } catch(e) {
  }

};
module.exports.tags = ["bscMainnet_lci_L2Vaults"];
