const { ethers } = require("hardhat");
const { common, ethRinkeby: network_ } = require("../../parameters/testnet");
const AddressZero = ethers.constants.AddressZero;

module.exports = async ({ deployments }) => {
  const { deploy } = deployments;
  const [deployer] = await ethers.getSigners();

  const STI = await ethers.getContractFactory("STI");
  const stiProxy = await ethers.getContract("STI_Proxy");
  const sti = STI.attach(stiProxy.address);

  const priceOracleProxy = await ethers.getContract("EthPriceOracleTest_Proxy");

  console.log("Now deploying STIMinterTest...");
  const proxy = await deploy("STIMinterTest", {
    from: deployer.address,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            common.admin, AddressZero, network_.biconomy,
            sti.address, priceOracleProxy.address,
          ],
        },
      },
    },
  });
  console.log("  STIMinterTest_Proxy contract address: ", proxy.address);

  const minter = await sti.minter();
  if (minter === AddressZero) {
    const tx = await sti.setMinter(proxy.address);
    await tx.wait();
  }

  // Verify the implementation contract
  try {
    const implSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"; // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)

    let implAddress = await ethers.provider.getStorageAt(proxy.address, implSlot);
    implAddress = implAddress.replace("0x000000000000000000000000", "0x");

    await run("verify:verify", {
      address: implAddress,
      contract: "contracts/sti/STIMinterTest.sol:STIMinterTest",
    });
  } catch (e) {
  }
};
module.exports.tags = ["ethRinkeby_sti_STIMinter"];
