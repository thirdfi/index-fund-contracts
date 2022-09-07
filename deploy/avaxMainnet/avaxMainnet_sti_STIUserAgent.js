const { ethers } = require("hardhat");
const { common } = require('../../parameters');
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying STIUserAgentSub ...");
  const subImpl = await deploy("STIUserAgentSub", {
    from: deployer.address,
  });
  console.log("  STIUserAgentSub contract address: ", subImpl.address);

  const swapProxy = await ethers.getContract("AvaxSwap_Proxy");
  const mchainAdapterProxy = await ethers.getContract("MultichainXChainAdapter_Proxy");
  const cbridgeAdapterProxy = await ethers.getContract("CBridgeXChainAdapter_Proxy");
  const minterProxy = await ethers.getContract("STIMinter_Proxy");
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
  console.log("  STIUserAgent_Proxy contract address: ", proxy.address);

  const STIUserAgent = await ethers.getContractFactory("STIUserAgent");
  const userAgent = STIUserAgent.attach(proxy.address);
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

  const STIMinter = await ethers.getContractFactory("STIMinter");
  const minter = STIMinter.attach(minterProxy.address);
  if (await minter.userAgent() === AddressZero) {
    const tx = await minter.setUserAgent(proxy.address);
    await tx.wait();
  }

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
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");
    
    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/xchain/agent/STIUserAgent.sol:STIUserAgent",
    });
  } catch(e) {
  }

};
module.exports.tags = ["avaxMainnet_sti_STIUserAgent"];
