const { ethers } = require("hardhat");
const { common } = require('../../parameters/testnet');
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying STIUserAgentSub ...");
  const subImpl = await deploy("STIUserAgentSub", {
    from: deployer.address,
  });
  console.log("  STIUserAgentSub contract address: ", subImpl.address);

  const swapProxy = await ethers.getContract("BscSwap_Proxy");
  const mchainAdapterProxy = await ethers.getContract("MultichainXChainAdapter_Proxy");
  const cbridgeAdapterProxy = await ethers.getContract("CBridgeXChainAdapter_Proxy");
  const minterAddress = AddressZero;
  const vaultProxy = await ethers.getContract("STIVault_Proxy");

  console.log("Now deploying STIUserAgent...");
  const proxy = await deploy("STIUserAgent", {
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
            minterAddress, vaultProxy.address,
          ],
        },
      },
    },
  });
  console.log("  STIUserAgent_Proxy contract address: ", proxy.address);

  const STIVault = await ethers.getContractFactory("STIVault");
  const vault = STIVault.attach(vaultProxy.address);
  if (await vault.userAgent() === AddressZero) {
    const tx = await vault.setUserAgent(proxy.address);
    await tx.wait();
  }

  // Verify the implementation contract
  try {
    await run("verify:verify", {
      address: subImpl.address,
      contract: "contracts/xchain/agent/STIUserAgentSub.sol:STIUserAgentSub",
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
            minterAddress, vaultProxy.address,
      ],
      contract: "contracts/xchain/agent/STIUserAgent.sol:STIUserAgent",
    });
  } catch(e) {
  }

};
module.exports.tags = ["bscTestnet_sti_STIUserAgent"];
