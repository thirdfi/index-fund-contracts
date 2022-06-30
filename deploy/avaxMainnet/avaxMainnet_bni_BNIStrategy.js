const { ethers } = require("hardhat");
const { common, avaxMainnet: network_ } = require("../../parameters");
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  const priceOracleProxy = await ethers.getContract("AvaxPriceOracle_Proxy");

  console.log("Now deploying AvaxBNIStrategy...");
  const proxy = await deploy("AvaxBNIStrategy", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            common.treasury, common.admin,
            priceOracleProxy.address,
            network_.Swap.router, network_.Swap.SWAP_BASE_TOKEN,
            network_.Swap.USDT, network_.Swap.WAVAX
          ],
        },
      },
    },
  });
  console.log("  AvaxBNIStrategy_Proxy contract address: ", proxy.address);

  const AvaxBNIStrategy = await ethers.getContractFactory("AvaxBNIStrategy");
  const strategy = AvaxBNIStrategy.attach(proxy.address);
  const WAVAXVault = await strategy.WAVAXVault();
  if (WAVAXVault === AddressZero) {
    const vaultFactory = await ethers.getContract("Aave3VaultFactory");
    const WAVAXVaultAddr = await vaultFactory.getVaultByUnderlying(network_.Token.WAVAX);
    const tx = await strategy.setWAVAXVault(WAVAXVaultAddr);
    await tx.wait();
  }

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/bni/strategy/AvaxBNIStrategy.sol:AvaxBNIStrategy",
    });
  } catch (e) {
  }
};
module.exports.tags = ["avaxMainnet_bni_BNIStrategy"];
