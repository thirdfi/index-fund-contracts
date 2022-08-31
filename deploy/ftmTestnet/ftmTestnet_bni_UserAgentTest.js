const { ethers } = require("hardhat");
const { common, ftmTestnet: network_ } = require('../../parameters/testnet');
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying UserAgentSubTest ...");
  const subImpl = await deploy("UserAgentSubTest", {
    from: deployer.address,
  });
  console.log("  UserAgentSubTest contract address: ", subImpl.address);

  const swapProxy = await ethers.getContract("FtmSwapTest_Proxy");
  const mchainAdapterProxy = await ethers.getContract("MultichainXChainAdapterTest_Proxy");
  const cbridgeAdapterProxy = await ethers.getContract("CBridgeXChainAdapterTest_Proxy");
  const minterAddress = AddressZero;
  const vaultProxy = await ethers.getContract("BNIVaultTest_Proxy");

  console.log("Now deploying UserAgentTest...");
  const proxy = await deploy("UserAgentTest", {
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
  console.log("  UserAgentTest_Proxy contract address: ", proxy.address);

  const UserAgentTest = await ethers.getContractFactory("UserAgentTest");
  const userAgent = UserAgentTest.attach(proxy.address);
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
      contract: "contracts/xchain/agent/test/UserAgentSubTest.sol:UserAgentSubTest",
    });
  } catch(e) {
  }
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");
    
    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/xchain/agent/test/UserAgentTest.sol:UserAgentTest",
    });
  } catch(e) {
  }

};
module.exports.tags = ["ftmTestnet_bni_UserAgentTest"];
