const { ethers } = require("hardhat");
const { common } = require("../../parameters");
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  const priceOracleProxy = await ethers.getContract("EthPriceOracle_Proxy");

  // Deploy the StVault
  console.log("Now deploying EthStETHVault...");
  const proxy = await deploy("EthStETHVault", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize1",
          args: [
            common.treasury, common.admin,
            priceOracleProxy.address,
          ],
        },
      },
    },
  });
  console.log("  EthStETHVault_Proxy contract address: ", proxy.address);
  const STVault = await ethers.getContractFactory("EthStETHVault");
  const stVault = STVault.attach(proxy.address);

  // Deploy the StVaultNFT
  const nftArtifact = await deployments.getArtifact("StVaultNFT");
  const nftIface = new ethers.utils.Interface(JSON.stringify(nftArtifact.abi));

  const nftFactory = await ethers.getContract("StVaultNFTFactory");

  const dataStVaultNft = nftIface.encodeFunctionData("initialize", [
    "STI Staking ETH NFT", "stiStETHNft",
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
      contract: "contracts/stVaults/lido/EthStETHVault.sol:EthStETHVault",
    });
  } catch (e) {
  }
  try {
    await run("verify:verify", {
      address: stVaultNftAddr,
      constructorArguments: [
        await nftFactory.getBeacon(),
        dataStVaultNft
      ],
      contract: "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol:BeaconProxy",
    });
  } catch(e) {
  }
};
module.exports.tags = ["ethMainnet_sti_StETH"];
