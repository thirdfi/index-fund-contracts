const { ethers } = require("hardhat");
const { common, auroraMainnet: network_ } = require("../../parameters");
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  const strategyProxy = await ethers.getContract("AuroraBNIStrategy_Proxy");
  const BNIStrategy = await ethers.getContractFactory("AuroraBNIStrategy");
  const strategy = BNIStrategy.attach(strategyProxy.address);

  const priceOracleProxy = await ethers.getContract("AuroraPriceOracle_Proxy");
  var userAgentProxy;
  try {
    userAgentProxy = await ethers.getContract("BNIUserAgent_Proxy");
  } catch(e) {
    userAgentProxy = AddressZero;
  }

  console.log("Now deploying BNIVault...");
  const proxy = await deploy("BNIVault", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            common.treasury, common.admin,
            strategy.address, priceOracleProxy.address,
            network_.Swap.USDT,
          ],
        },
        onUpgrade: {
          methodName: "initialize2",
          args: [
            userAgentProxy.address,
            network_.biconomy,
          ],
        }
      },
    },
  });
  console.log("  BNIVault_Proxy contract address: ", proxy.address);

  if ((await strategy.vault()) === ethers.constants.AddressZero) {
    const tx = await strategy.setVault(proxy.address);
    await tx.wait();
  }

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/bni/BNIVault.sol:BNIVault",
    });
  } catch (e) {
  }
};
module.exports.tags = ["auroraMainnet_bni_BNIVault"];
