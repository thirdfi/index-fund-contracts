const { ethers } = require("hardhat");
const { common, maticMumbai: network_ } = require("../../parameters/testnet");
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {

  const vaultArtifact = await deployments.getArtifact("BasicAave3VaultTest");
  const vaultIface = new ethers.utils.Interface(JSON.stringify(vaultArtifact.abi));

  const priceOracleProxy = await ethers.getContract("MaticPriceOracleTest_Proxy");
  const vaultFactory = await ethers.getContract("Aave3VaultFactory");

  const dataWMATIC = vaultIface.encodeFunctionData("initialize", [
    "BNI L2 WMATIC", "bniL2WMATIC",
    common.treasury, common.admin,
    priceOracleProxy.address,
    network_.Aave3.aPolWMATIC,
  ]);

  if (await vaultFactory.getVaultByUnderlying(network_.Swap.WMATIC) === AddressZero) {
    console.log("Now deploying WMATICVault ...");
    const tx = await vaultFactory.createVault(network_.Swap.WMATIC, dataWMATIC);
    await tx.wait();
    const vaultAddr = await vaultFactory.getVaultByUnderlying(network_.Swap.WMATIC)
    console.log("  WMATICVaultAddr: ", vaultAddr);
  }

  // Verify the contracts
  try {
    await run("verify:verify", {
      address: await vaultFactory.getVaultByUnderlying(network_.Swap.WMATIC),
      constructorArguments: [
        await vaultFactory.getBeacon(),
        dataWMATIC
      ],
      contract: "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol:BeaconProxy",
    });
  } catch(e) {
  }

};
module.exports.tags = ["maticMumbai_l2_Aave3Vaults"];
