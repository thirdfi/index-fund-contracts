const { ethers } = require("hardhat");
const { common, avaxMainnet: network_ } = require("../../parameters");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  const strategyProxy = await ethers.getContract("MWIStrategy_Proxy");
  const MWIStrategy = await ethers.getContractFactory("MWIStrategy");
  const strategy = MWIStrategy.attach(strategyProxy.address);

  console.log("Now deploying MWIVault...");
  const proxy = await deploy("MWIVault", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            common.treasury, common.admin,
            network_.biconomy, strategy.address,
          ],
        },
      },
    },
  });
  console.log("  MWIVault_Proxy contract address: ", proxy.address);

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
      contract: "contracts/mwi/MWIVault.sol:MWIVault",
    });
  } catch (e) {
  }
};
module.exports.tags = ["avaxMainnet_mwi_MWIVault"];
