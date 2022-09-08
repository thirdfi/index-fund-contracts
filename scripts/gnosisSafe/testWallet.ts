const { ethers } = require("hardhat");
import Safe from 'gnosis-safe-core-sdk-e'
import EthersAdapter from '@gnosis.pm/safe-ethers-lib'

async function main() {
  const [deployer] = await ethers.getSigners();
  let safeSdk: Safe;
  let safeAddress = "0x197a3b523f35675Cf724d7edf7f5A5F93f24D226";

  const ethAdapter = new EthersAdapter({
    ethers,
    signer: deployer
  })
  safeSdk = await Safe.create({ ethAdapter: ethAdapter, safeAddress })
  console.log(`  Owners: ${await safeSdk.getOwners()}`);
  console.log(`  Threshold: ${await safeSdk.getThreshold()}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })