const { ethers } = require("hardhat");
const param = require('../../parameters/testnet');
const { common, auroraTestnet: network_ } = require('../../parameters/testnet');
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  console.log("Now deploying BNIUserAgentSubTest ...");
  const subImpl = await deploy("BNIUserAgentSubTest", {
    from: deployer.address,
  });
  console.log("  BNIUserAgentSubTest contract address: ", subImpl.address);

  const swapProxy = await ethers.getContract("AuroraSwapTest_Proxy");
  const mchainAdapterAddress = AddressZero;;
  const cbridgeAdapterProxy = await ethers.getContract("CBridgeXChainAdapterTest_Proxy");
  const minterAddress = AddressZero;
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
            mchainAdapterAddress, cbridgeAdapterProxy.address,
            minterAddress, vaultProxy.address,
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
      await tx.wait();
    } catch(e) {
      console.error(`===> Check ether the deployer is the owner of the userAgent contract.`)
    }
  }

  const CBridgeXChainAdapterTest = await ethers.getContractFactory("CBridgeXChainAdapterTest");
  const cbridgeAdapter = CBridgeXChainAdapterTest.attach(cbridgeAdapterProxy.address);
  const CLIENT_ROLE = await cbridgeAdapter.CLIENT_ROLE();
  if (await cbridgeAdapter.hasRole(CLIENT_ROLE, proxy.address) === false) {
    const tx = await cbridgeAdapter.grantRole(CLIENT_ROLE, proxy.address);
    await tx.wait();
  }

  try {
    const BNIVaultTest = await ethers.getContractFactory("BNIVaultTest");
    const vault = BNIVaultTest.attach(vaultProxy.address);
    if (await vault.userAgent() === AddressZero) {
      const tx = await vault.initialize2(proxy.address, network_.biconomy);
      await tx.wait();
    }
  } catch(e) {
    console.log(e);
  }

  // Multichain is not supported on Aurora
  try {
    if (await userAgent.callAdapterTypes(param.avaxTestnet.chainId) == 0) {
      const tx = await userAgent.setCallAdapterTypes([
        param.avaxTestnet.chainId,
        param.bscTestnet.chainId,
        param.ethRinkeby.chainId,
        param.maticMumbai.chainId,
      ],[
        1,
        1,
        1,
        1,
      ]);
      await tx.wait();
    }
  } catch(e) {
    console.log(e);
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
module.exports.tags = ["auroraTestnet_bni_BNIUserAgent"];
