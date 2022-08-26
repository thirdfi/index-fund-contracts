const { ethers } = require("hardhat");
const { maticMainnet: network_ } = require('../../parameters');

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying CBridgeXChainAdapter...");
  const proxy = await deploy("CBridgeXChainAdapter", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize1",
          args: [
            network_.cBridge.messageBus,
          ],
        },
      },
    },
  });
  console.log("  CBridgeXChainAdapter_Proxy contract address: ", proxy.address);

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/xchain/cbridge/CBridgeXChainAdapter.sol:CBridgeXChainAdapter",
    });
  } catch (e) {
  }
};
module.exports.tags = ["maticMainnet_xchain_CBridgeXChainAdapter"];
