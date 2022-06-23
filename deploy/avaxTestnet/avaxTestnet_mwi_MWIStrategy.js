const { ethers } = require("hardhat");
const { avaxTestnet: network_ } = require("../../parameters/testnet");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  const avaxVaultFactory = await ethers.getContract("Aave3VaultFactory");
  const totalVaults = await avaxVaultFactory.totalVaults();
  if (totalVaults < 4) {
    console.error("No L2 vaults deployed");
    process.exit(1);
  }

  const WBTCVaultAddr = await avaxVaultFactory.getVaultByUnderlying(network_.Token.WBTC);
  const WETHVaultAddr = await avaxVaultFactory.getVaultByUnderlying(network_.Token.WETH);
  const WAVAXVaultAddr = await avaxVaultFactory.getVaultByUnderlying(network_.Token.WAVAX);
  const USDTVaultAddr = await avaxVaultFactory.getVaultByUnderlying(network_.Token.USDt);

  console.log("Now deploying MWIStrategy...");
  const proxy = await deploy("MWIStrategyTest", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            WBTCVaultAddr,
            WETHVaultAddr,
            WAVAXVaultAddr,
            USDTVaultAddr,
          ],
        },
      },
    },
  });
  console.log("  MWIStrategy_Proxy contract address: ", proxy.address);

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/mwi/MWIStrategyTest.sol:MWIStrategyTest",
    });
  } catch (e) {
  }
};
module.exports.tags = ["avaxTestnet_mwi_MWIStrategy"];
