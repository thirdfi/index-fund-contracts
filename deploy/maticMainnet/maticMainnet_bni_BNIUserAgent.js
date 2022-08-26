const { ethers } = require("hardhat");
const { common } = require('../../parameters');

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying BNIUserAgentSub ...");
  const subImpl = await deploy("BNIUserAgentSub", {
    from: deployer.address,
  });
  console.log("  BNIUserAgentSub contract address: ", subImpl.address);

  const swapProxy = await ethers.getContract("AvaxSwap_Proxy");
  const mchainAdapterProxy = await ethers.getContract("MultichainXChainAdapter_Proxy");
  const cbridgeAdapterProxy = await ethers.getContract("CBridgeXChainAdapter_Proxy");
  const minterProxy = ethers.constants.AddressZero;
  const vaultProxy = await ethers.getContract("BNIVault_Proxy");

  console.log("Now deploying BNIUserAgent...");
  const proxy = await deploy("BNIUserAgent", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize1",
          args: [
            subImpl.address,
            common.admin,
            swapProxy.address,
            mchainAdapterProxy.address, cbridgeAdapterProxy.address,
            minterProxy.address, vaultProxy.address,
          ],
        },
      },
    },
  });
  console.log("  BNIUserAgent_Proxy contract address: ", proxy.address);

  // Verify the implementation contract
  try {
    await run("verify:verify", {
      address: subImpl.address,
      contract: "contracts/xchain/agent/BNIUserAgentSub.sol:BNIUserAgentSub",
    });
  } catch(e) {
  }
  try {
    await run("verify:verify", {
      address: proxy.address,
      constructorArguments: [
        subImpl.address,
            common.admin,
            swapProxy.address,
            mchainAdapterProxy.address, cbridgeAdapterProxy.address,
            minterProxy.address, vaultProxy.address,
      ],
      contract: "contracts/xchain/agent/BNIUserAgent.sol:BNIUserAgent",
    });
  } catch(e) {
  }

};
module.exports.tags = ["maticMainnet_bni_BNIUserAgent"];
