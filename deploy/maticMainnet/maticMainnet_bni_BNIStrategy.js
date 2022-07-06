const { ethers } = require("hardhat");
const { common, maticMainnet: network_ } = require("../../parameters");
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  const priceOracleProxy = await ethers.getContract("MaticPriceOracle_Proxy");

  console.log("Now deploying MaticBNIStrategy...");
  const proxy = await deploy("MaticBNIStrategy", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            common.treasury, common.admin,
            priceOracleProxy.address,
            network_.Swap.router, network_.Swap.SWAP_BASE_TOKEN,
            network_.Swap.USDT, network_.Swap.WMATIC
          ],
        },
      },
    },
  });
  console.log("  MaticBNIStrategy_Proxy contract address: ", proxy.address);

  try {
    const MaticBNIStrategy = await ethers.getContractFactory("MaticBNIStrategy");
    const strategy = MaticBNIStrategy.attach(proxy.address);
    const WMATICVault = await strategy.WMATICVault();
    if (WMATICVault === AddressZero) {
      const vaultFactory = await ethers.getContract("Aave3VaultFactory");
      const WMATICVaultAddr = await vaultFactory.getVaultByUnderlying(network_.Swap.WMATIC);
      const tx = await strategy.setWMATICVault(WMATICVaultAddr);  // It can be failed if the deployer is not owner of the SC
      await tx.wait();
    }
  } catch(e) {
  }

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/bni/strategy/MaticBNIStrategy.sol:MaticBNIStrategy",
    });
  } catch (e) {
  }
};
module.exports.tags = ["maticMainnet_bni_BNIStrategy"];
