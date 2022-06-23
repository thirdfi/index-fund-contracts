const { ethers } = require("hardhat");
const { bscMainnet: network_ } = require("../../parameters");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  const bscVaultFactory = await ethers.getContract("PckFarm2VaultFactory");
  const totalVaults = await bscVaultFactory.totalVaults();
  if (totalVaults < 3) {
    console.error("No L2 vaults deployed");
    process.exit(1);
  }

  const USDTUSDCVaultAddr = await bscVaultFactory.getVaultByPid(network_.PancakeSwap.Farm_USDT_USDC_pid);
  const USDTBUSDVaultAddr = await bscVaultFactory.getVaultByPid(network_.PancakeSwap.Farm_USDT_BUSD_pid);
  const USDCBUSDVaultAddr = await bscVaultFactory.getVaultByPid(network_.PancakeSwap.Farm_USDC_BUSD_pid);

  console.log("Now deploying LCIStrategy...");
  const proxy = await deploy("LCIStrategy", {
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
      contract: "contracts/lci/LCIStrategy.sol:LCIStrategy",
    });
  } catch (e) {
  }
};
module.exports.tags = ["bscMainnet_lci_LCIStrategy"];
