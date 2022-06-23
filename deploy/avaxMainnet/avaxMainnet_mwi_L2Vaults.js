const { ethers } = require("hardhat");
const { common, avaxMainnet: network_ } = require("../../parameters");
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {

  const vaultArtifact = await deployments.getArtifact("Aave3Vault");
  const vaultIface = new ethers.utils.Interface(JSON.stringify(vaultArtifact.abi));

  const avaxVaultFactory = await ethers.getContract("Aave3VaultFactory");

  const dataWBTC = vaultIface.encodeFunctionData("initialize", [
    "MWI L2 WBTC", "mwiL2WBTC",
    network_.Aave3.aAvaWBTC,
    common.treasury, common.admin,
  ]);

  if (await avaxVaultFactory.getVaultByUnderlying(network_.Token.WBTC) === AddressZero) {
    console.log("Now deploying WBTCVault ...");
    const tx = await avaxVaultFactory.createVault(network_.Token.WBTC, dataWBTC);
    await tx.wait();
    const WBTCVaultAddr = await avaxVaultFactory.getVault((await avaxVaultFactory.totalVaults()).sub(1))
    console.log("  WBTCVaultAddr: ", WBTCVaultAddr);
  }

  if (await avaxVaultFactory.getVaultByUnderlying(network_.Token.WETH) === AddressZero) {
    console.log("Now deploying WETHVault ...");
    const dataWETH= vaultIface.encodeFunctionData("initialize", [
      "MWI L2 WETH", "mwiL2WETH",
      network_.Aave3.aAvaWETH,
      common.treasury, common.admin,
    ]);

    const tx = await avaxVaultFactory.createVault(network_.Token.WETH, dataWETH);
    await tx.wait();
    const WETHVaultAddr = await avaxVaultFactory.getVault((await avaxVaultFactory.totalVaults()).sub(1))
    console.log("  WETHVaultAddr: ", WETHVaultAddr);
  }

  if (await avaxVaultFactory.getVaultByUnderlying(network_.Token.WAVAX) === AddressZero) {
    console.log("Now deploying WAVAXVault ...");
    const dataWAVAX= vaultIface.encodeFunctionData("initialize", [
      "MWI L2 WAVAX", "mwiL2WAVAX",
      network_.Aave3.aAvaWAVAX,
      common.treasury, common.admin,
    ]);

    const tx = await avaxVaultFactory.createVault(network_.Token.WAVAX, dataWAVAX);
    await tx.wait();
    const WAVAXVaultAddr = await avaxVaultFactory.getVault((await avaxVaultFactory.totalVaults()).sub(1))
    console.log("  WAVAXVaultAddr: ", WAVAXVaultAddr);
  }

  if (await avaxVaultFactory.getVaultByUnderlying(network_.Token.USDt) === AddressZero) {
    console.log("Now deploying USDTVault ...");
    const dataUSDT= vaultIface.encodeFunctionData("initialize", [
      "MWI L2 USDT", "mwiL2USDT",
      network_.Aave3.aAvaUSDT,
      common.treasury, common.admin,
    ]);

    const tx = await avaxVaultFactory.createVault(network_.Token.USDt, dataUSDT);
    await tx.wait();
    const USDTVaultAddr = await avaxVaultFactory.getVault((await avaxVaultFactory.totalVaults()).sub(1))
    console.log("  USDTVaultAddr: ", USDTVaultAddr);
  }

  // Verify the contracts
  try {
    await run("verify:verify", {
      address: await avaxVaultFactory.getVault(0),
      constructorArguments: [
        await avaxVaultFactory.getBeacon(),
        dataWBTC
      ],
      contract: "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol:BeaconProxy",
    });
  } catch(e) {
  }

};
module.exports.tags = ["avaxMainnet_mwi_L2Vaults"];
