const { ethers } = require("hardhat");
const { common, avaxTestnet: network_ } = require('../../parameters/testnet');
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying BNIUserAgentSubTest ...");
  const subImpl = await deploy("BNIUserAgentSubTest", {
    from: deployer.address,
  });
  console.log("  BNIUserAgentSubTest contract address: ", subImpl.address);

  const swapProxy = await ethers.getContract("AvaxSwapTest_Proxy");
  const mchainAdapterProxy = await ethers.getContract("MultichainXChainAdapterTest_Proxy");
  const cbridgeAdapterProxy = await ethers.getContract("CBridgeXChainAdapterTest_Proxy");
  const minterProxy = await ethers.getContract("BNIMinterTest_Proxy");
  const vaultProxy = await ethers.getContract("BNIVaultTest_Proxy");

  console.log("Now deploying BNIUserAgentTest...");
  const proxy = await deploy("BNIUserAgentTest", {
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
  console.log("  BNIUserAgentTest_Proxy contract address: ", proxy.address);

  const BNIUserAgentTest = await ethers.getContractFactory("BNIUserAgentTest");
  const userAgent = BNIUserAgentTest.attach(proxy.address);
  if (await userAgent.subImpl() != subImpl.address) {
    // It needs to update subImpl address because the subImpl contract is redeployed.
    try {
      const tx = await userAgent.setSubImpl(subImpl.address);
      tx.wait();
    } catch(e) {
      console.error(`===> Check ether the deployer is the owner of the userAgent contract.`)
    }
  }

  const MultichainXChainAdapterTest = await ethers.getContractFactory("MultichainXChainAdapterTest");
  const mchainAdapter = MultichainXChainAdapterTest.attach(mchainAdapterProxy.address);
  const CLIENT_ROLE = await mchainAdapter.CLIENT_ROLE();
  if (await mchainAdapter.hasRole(CLIENT_ROLE, proxy.address) === false) {
    const tx = await mchainAdapter.grantRole(CLIENT_ROLE, proxy.address);
    tx.wait();
  }
  const CBridgeXChainAdapterTest = await ethers.getContractFactory("CBridgeXChainAdapterTest");
  const cbridgeAdapter = CBridgeXChainAdapterTest.attach(cbridgeAdapterProxy.address);
  if (await cbridgeAdapter.hasRole(CLIENT_ROLE, proxy.address) === false) {
    const tx = await cbridgeAdapter.grantRole(CLIENT_ROLE, proxy.address);
    tx.wait();
  }

  try {
    const BNIMinterTest = await ethers.getContractFactory("BNIMinterTest");
    const minter = BNIMinterTest.attach(minterProxy.address);
    if (await minter.userAgent() === AddressZero) {
      const tx = await minter.initialize2(proxy.address, network_.biconomy);
      await tx.wait();
    }

    const BNIVaultTest = await ethers.getContractFactory("BNIVaultTest");
    const vault = BNIVaultTest.attach(vaultProxy.address);
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
      contract: "contracts/xchain/agent/BNIUserAgentSubTest.sol:BNIUserAgentSubTest",
    });
  } catch(e) {
  }
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");
    
    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/xchain/agent/BNIUserAgentTest.sol:BNIUserAgentTest",
    });
  } catch(e) {
  }

};
module.exports.tags = ["avaxTestnet_bni_BNIUserAgent"];
