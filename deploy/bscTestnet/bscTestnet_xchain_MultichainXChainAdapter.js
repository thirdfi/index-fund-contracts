const { ethers, network } = require("hardhat");
const { bscTestnet: network_ } = require('../../parameters/testnet');

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  if (network.config.chainId !== network_.chainId) {
    console.warn(`MultichainXChainAdapter needs to deploy on the correct network`);
    console.warn(`  Check if the --network parameter is correct`);
    console.warn(`  Or check if the process.env.CHAIN_ID=${network_.chainId} if it runs on hardhat`);
  }

  console.log("Now deploying MultichainXChainAdapter...");
  const proxy = await deploy("MultichainXChainAdapter", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [],
        },
      },
    },
  });
  console.log("  MultichainXChainAdapter_Proxy contract address: ", proxy.address);

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/xchain/multichain/MultichainXChainAdapter.sol:MultichainXChainAdapter",
    });
  } catch (e) {
  }
};
module.exports.tags = ["bscTestnet_xchain_MultichainXChainAdapter"];
