const { ethers } = require("hardhat");
const { common, auroraMainnet: network_ } = require("../../parameters");
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  const priceOracleProxy = await ethers.getContract("AuroraPriceOracle_Proxy");

  console.log("Now deploying AuroraBNIStrategy...");
  const proxy = await deploy("AuroraBNIStrategy", {
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
            network_.Swap.USDT, network_.Swap.WNEAR
          ],
        },
      },
    },
  });
  console.log("  AuroraBNIStrategy_Proxy contract address: ", proxy.address);

  const AuroraBNIStrategy = await ethers.getContractFactory("AuroraBNIStrategy");
  const strategy = AuroraBNIStrategy.attach(proxy.address);
  const WNEARVault = await strategy.WNEARVault();
  if (WNEARVault === AddressZero) {
    const vaultFactory = await ethers.getContract("CompoundVaultFactory");
    const WNEARVaultAddr = await vaultFactory.getVaultByUnderlying(network_.Swap.WNEAR);
    const tx = await strategy.setWNEARVault(WNEARVaultAddr);
    await tx.wait();
  }

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/bni/strategy/AuroraBNIStrategy.sol:AuroraBNIStrategy",
    });
  } catch (e) {
  }
};
module.exports.tags = ["auroraMainnet_bni_BNIStrategy"];
