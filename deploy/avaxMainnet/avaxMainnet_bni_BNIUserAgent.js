const { ethers } = require("hardhat");
const { common, avaxMainnet: network_ } = require('../../parameters');
const AddressZero = ethers.constants.AddressZero;

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
  const minterProxy = await ethers.getContract("BNIMinter_Proxy");
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
            common.treasury,
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

  const BNIUserAgent = await ethers.getContractFactory("BNIUserAgent");
  const userAgent = BNIUserAgent.attach(proxy.address);
  if (await userAgent.subImpl() != subImpl.address) {
    // It needs to update subImpl address because the subImpl contract is redeployed.
    try {
      const tx = await userAgent.setSubImpl(subImpl.address);
      await tx.wait();
    } catch(e) {
      console.error(`===> Check ether the deployer is the owner of the userAgent contract.`)
    }
  }

  const MultichainXChainAdapter = await ethers.getContractFactory("MultichainXChainAdapter");
  const mchainAdapter = MultichainXChainAdapter.attach(mchainAdapterProxy.address);
  const CLIENT_ROLE = await mchainAdapter.CLIENT_ROLE();
  if (await mchainAdapter.hasRole(CLIENT_ROLE, proxy.address) === false) {
    const tx = await mchainAdapter.grantRole(CLIENT_ROLE, proxy.address);
    await tx.wait();
  }
  const CBridgeXChainAdapter = await ethers.getContractFactory("CBridgeXChainAdapter");
  const cbridgeAdapter = CBridgeXChainAdapter.attach(cbridgeAdapterProxy.address);
  if (await cbridgeAdapter.hasRole(CLIENT_ROLE, proxy.address) === false) {
    const tx = await cbridgeAdapter.grantRole(CLIENT_ROLE, proxy.address);
    await tx.wait();
  }

  const BNIMinter = await ethers.getContractFactory("BNIMinter");
  const minter = BNIMinter.attach(minterProxy.address);
  if (await minter.userAgent() === AddressZero) {
    const tx = await minter.initialize2(proxy.address, network_.biconomy);
    await tx.wait();
  }

  try {
    const BNIMinter = await ethers.getContractFactory("BNIMinter");
    const minter = BNIMinter.attach(minterProxy.address);
    if (await minter.userAgent() === AddressZero) {
      const tx = await minter.initialize2(proxy.address, network_.biconomy);
      await tx.wait();
    }

    const BNIVault = await ethers.getContractFactory("BNIVault");
    const vault = BNIVault.attach(vaultProxy.address);
    if (await vault.userAgent() === AddressZero) {
      const tx = await vault.initialize2(proxy.address, network_.biconomy);
      await tx.wait();
    }
  } catch(e) {
  }

  // Verify the implementation contract
  try {
    await run("verify:verify", {
      address: subImpl.address,
      contract: "contracts/xchain/agent/BNIUserAgentSub.sol:BNIUserAgentSub",
    });
  } catch(e) {
  }
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");
    
    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/xchain/agent/BNIUserAgent.sol:BNIUserAgent",
    });
  } catch(e) {
  }

};
module.exports.tags = ["avaxMainnet_bni_BNIUserAgent"];
