const { ethers } = require("hardhat");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  const bscVaultFactory = await ethers.getContract("BscVaultFactory");
  const totalVaults = await bscVaultFactory.totalVaults();
  if (totalVaults < 3) {
    console.error("No L2 vaults deployed");
    process.exit(1);
  }

  const USDTUSDCVaultAddr = await bscVaultFactory.getVault(0);
  const USDTBUSDVaultAddr = await bscVaultFactory.getVault(1);
  const USDCBUSDVaultAddr = await bscVaultFactory.getVault(2);

  console.log("Now deploying LCIStrategy...");
  const proxy = await deploy("LCIStrategyTest", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            USDTUSDCVaultAddr,
            USDTBUSDVaultAddr,
            USDCBUSDVaultAddr,
          ],
        },
      },
    },
  });
  console.log("  LCIStrategy_Proxy contract address: ", proxy.address);

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/lci/LCIStrategyTest.sol:LCIStrategyTest",
    });
  } catch (e) {
  }
};
module.exports.tags = ["bscTestnet_lci_LCIStrategy"];
