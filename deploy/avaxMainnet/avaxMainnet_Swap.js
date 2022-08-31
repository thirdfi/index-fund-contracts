const { ethers } = require("hardhat");
const { avaxMainnet: network_ } = require("../../parameters");

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying AvaxSwap...");
  const proxy = await deploy("AvaxSwap", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            network_.Swap.router, network_.Swap.SWAP_BASE_TOKEN,
          ],
        },
      },
    },
  });
  console.log("  AvaxSwap_Proxy contract address: ", proxy.address);

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/swap/AvaxSwap.sol:AvaxSwap",
    });
  } catch (e) {
  }
};
module.exports.tags = ["avaxMainnet_Swap"];