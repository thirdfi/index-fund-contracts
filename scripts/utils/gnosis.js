"use strict";
const { ethers, network } = require("hardhat")
const EthersAdapter = require('@gnosis.pm/safe-ethers-lib');
const Safe = require('@gnosis.pm/safe-core-sdk');

const GnosisSafe_ABI = [
  "function getOwners() external view returns (address[] memory)",
  "function getThreshold() external view returns (uint256)",
];

function newAdapter(signer) {
  console.log(`===TEMP EthersAdapter=${EthersAdapter}`)
  console.log(`===TEMP EthersAdapter=${JSON.stringify(EthersAdapter)}`)
  return EthersAdapter({ethers, signer: signer});
}

async function createSafe(signer, safeAddress, isL1SafeMasterCopy=false) {
  const adapter = newAdapter(signer);
  const safeSdk = await Safe.create({
    ethAdapter: adapter,
    safeAddress: safeAddress,
    isL1SafeMasterCopy: isL1SafeMasterCopy
  });
  return safeSdk;
}

async function connectSafe(signer, safeAddress, isL1SafeMasterCopy=false) {
  const adapter = newAdapter(signer);
  const safeSdk = await Safe.connect({
    ethAdapter: adapter,
    safeAddress: safeAddress,
    isL1SafeMasterCopy: isL1SafeMasterCopy
  });
  return safeSdk;
}

async function impersonateAccount(ownerAddress) {
  await network.provider.request({method: "hardhat_impersonateAccount", params: [ownerAddress]});
}

async function executeMultisigTransaction(safeAddress, to, value, data) {
  [deployer] = await ethers.getSigners();
  const gnosisSafe = new ethers.Contract(safeAddress, GnosisSafe_ABI, deployer);
  const owners = await gnosisSafe.getOwners();
  const threshold = await gnosisSafe.getThreshold();

  for (let i = 0; i < threshold; i ++) {
    await impersonateAccount(owners[i]);
  }

  let safeSdk = await createSafe(await ethers.getSigner(owners[0]), safeAddress);
  const transaction = {
    to: to, // '0x<address>'
    value: value, // '<eth_value_in_wei>'
    data: data, // '0x<data>'
  }
  const safeTransaction = await safeSdk.createTransaction(transaction)

  for (let i = 1; i < threshold; i ++) {
    let safeSdk2 = await connectSafe(await ethers.getSigner(owners[i]), safeAddress);
    await safeSdk2.signTransaction(safeTransaction)
  }

  const executeTxResponse = await safeSdk.executeTransaction(safeTransaction)
  await executeTxResponse.transactionResponse?.wait()
}

module.exports = {
  executeMultisigTransaction,
}