const { ethers } = require("hardhat");
const { common, auroraMainnet: network_ } = require("../../parameters");
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  // Deploy the L2 vault to supply stNEAR to the Bastion
  const l2VaultArtifact = await deployments.getArtifact("AuroraBastionVault");
  const l2VaultIface = new ethers.utils.Interface(JSON.stringify(l2VaultArtifact.abi));

  const priceOracleProxy = await ethers.getContract("AuroraPriceOracle_Proxy");
  const l2VaultFactory = await ethers.getContract("CompoundVaultFactory");

  const dataStWNEAR = l2VaultIface.encodeFunctionData("initialize", [
    "STI L2 stNEAR", "stiL2stNEAR",
    common.treasury, common.admin,
    priceOracleProxy.address,
    network_.Bastion.cstNEAR1,
  ]);

  let l2StNEARVaultAddr = await l2VaultFactory.getVaultByUnderlying(network_.Token.stNEAR);
  if (l2StNEARVaultAddr === AddressZero) {
    console.log("Now deploying L2 stNEARVault ...");
    const tx = await l2VaultFactory.createVault(network_.Token.stNEAR, dataStWNEAR);
    await tx.wait();
    l2StNEARVaultAddr = await l2VaultFactory.getVaultByUnderlying(network_.Token.stNEAR)
    console.log("  L2 stNEARVault contract address: ", l2StNEARVaultAddr);
  }

  // Deploy the StVault
  console.log("Now deploying AuroraStNEARVault...");
  const proxy = await deploy("AuroraStNEARVault", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize1",
          args: [
            common.treasury, common.admin,
            priceOracleProxy.address,
            l2StNEARVaultAddr,
          ],
        },
      },
    },
  });
  console.log("  AuroraStNEARVault_Proxy contract address: ", proxy.address);
  const STVault = await ethers.getContractFactory("AuroraStNEARVault");
  const stVault = STVault.attach(proxy.address);

  // Deploy the StVaultNFT
  const nftArtifact = await deployments.getArtifact("StVaultNFT");
  const nftIface = new ethers.utils.Interface(JSON.stringify(nftArtifact.abi));

  const nftFactory = await ethers.getContract("StVaultNFTFactory");

  const dataStVaultNft = nftIface.encodeFunctionData("initialize", [
    "STI Staking WNEAR NFT", "stiStNEARNft",
    stVault.address,
  ]);

  let stVaultNftAddr = await nftFactory.getNFTByVault(stVault.address);
  if (stVaultNftAddr === AddressZero) {
    console.log("Now deploying StVaultNFT ...");
    const tx = await nftFactory.createNFT(stVault.address, dataStVaultNft);
    await tx.wait();
    stVaultNftAddr = await nftFactory.getNFTByVault(stVault.address)
    console.log("  StVaultNFT contract address: ", stVaultNftAddr);
  }

  if ((await stVault.nft()) === ethers.constants.AddressZero) {
    const tx = await stVault.setNFT(stVaultNftAddr);
    await tx.wait();
  }

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/stVaults/meta/AuroraStNEARVault.sol:AuroraStNEARVault",
    });
  } catch (e) {
  }
};
module.exports.tags = ["auroraMainnet_sti_StNEAR"];
