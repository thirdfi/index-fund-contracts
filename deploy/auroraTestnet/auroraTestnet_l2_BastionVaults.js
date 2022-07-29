const { ethers } = require("hardhat");
const { common, auroraTestnet: network_ } = require("../../parameters/testnet");
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {

  const vaultArtifact = await deployments.getArtifact("BasicCompoundVaultTest");
  const vaultIface = new ethers.utils.Interface(JSON.stringify(vaultArtifact.abi));

  const priceOracleProxy = await ethers.getContract("AuroraPriceOracleTest_Proxy");
  const vaultFactory = await ethers.getContract("CompoundVaultFactory");

  const dataWNEAR = vaultIface.encodeFunctionData("initialize", [
    "BNI L2 WNEAR", "bniL2WNEAR",
    common.treasury, common.admin,
    priceOracleProxy.address,
    network_.Bastion.cNEAR,
  ]);

  if (await vaultFactory.getVaultByUnderlying(network_.Swap.WNEAR) === AddressZero) {
    console.log("Now deploying WNEARVault ...");
    const tx = await vaultFactory.createVault(network_.Swap.WNEAR, dataWNEAR);
    await tx.wait();
    const vaultAddr = await vaultFactory.getVaultByUnderlying(network_.Swap.WNEAR)
    console.log("  WNEARVaultAddr: ", vaultAddr);
  }

  // Verify the contracts
  try {
    await run("verify:verify", {
      address: await vaultFactory.getVaultByUnderlying(network_.Swap.WNEAR),
      constructorArguments: [
        await vaultFactory.getBeacon(),
        dataWNEAR
      ],
      contract: "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol:BeaconProxy",
    });
  } catch(e) {
  }

};
module.exports.tags = ["auroraTestnet_l2_BastionVaults"];
