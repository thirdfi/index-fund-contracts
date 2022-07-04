const { ethers } = require("hardhat");
const { common, auroraMainnet: network_ } = require("../../parameters");
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {

  const vaultArtifact = await deployments.getArtifact("AuroraBastionVault");
  const vaultIface = new ethers.utils.Interface(JSON.stringify(vaultArtifact.abi));

  const priceOracleProxy = await ethers.getContract("AuroraPriceOracle_Proxy");
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
      address: vaultFactory.getVaultByUnderlying(network_.Swap.WNEAR),
      constructorArguments: [
        await vaultFactory.getBeacon(),
        dataWNEAR
      ],
      contract: "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol:BeaconProxy",
    });
  } catch(e) {
  }

};
module.exports.tags = ["auroraMainnet_l2_BastionVaults"];
