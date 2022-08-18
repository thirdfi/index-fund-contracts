"use strict";
const { ethers, network } = require("hardhat")
const AddressZero = ethers.constants.AddressZero;

const GnosisSafe_ABI = [
  "function nonce() external view returns (uint256)",
  "function getOwners() external view returns (address[] memory)",
  "function getThreshold() external view returns (uint256)",
  "function encodeTransactionData(address to,uint256 value,bytes calldata data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) external view returns (bytes memory)",
  "function getTransactionHash(address to,uint256 value,bytes memory data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) external view returns (bytes32)",
  "function approveHash(bytes32 hashToApprove) external",
  "function execTransaction(address to,uint256 value,bytes calldata data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address payable refundReceiver,bytes calldata signatures) external returns (bool success)",
];

async function createSafe(signer, safeAddress) {
  var safe = new Object({
    signer: signer,
    safeAddress: safeAddress,
    contract: new ethers.Contract(safeAddress, GnosisSafe_ABI, signer),
  })
  return safe;
}

async function createTransaction(safe, to, value, data) {
  return {
    to: to, // '0x<address>'
    value: value, // '<eth_value_in_wei>'
    data: data, // '0x<data>'
    operation: 0, // Call
    baseGas: 0,
    gasPrice: 0,
    gasToken: AddressZero,
    refundReceiver: AddressZero,
    nonce: (await safe.contract.nonce()).toNumber(),
    safeTxGas: 0,
    signatures: new Map(),
  }
}

async function signTransaction(safe, safeTransaction) {
  // const txHashData = await safe.contract.encodeTransactionData(
  //   safeTransaction.to, safeTransaction.value, safeTransaction.data,
  //   safeTransaction.operation, safeTransaction.safeTxGas, safeTransaction.baseGas,
  //   safeTransaction.gasPrice, safeTransaction.gasToken, safeTransaction.refundReceiver,
  //   safeTransaction.nonce
  // );
  // const txHash = '0x' + keccak256(txHashData).toString('hex');
  const txHash = await safe.contract.getTransactionHash(
    safeTransaction.to, safeTransaction.value, safeTransaction.data,
    safeTransaction.operation, safeTransaction.safeTxGas, safeTransaction.baseGas,
    safeTransaction.gasPrice, safeTransaction.gasToken, safeTransaction.refundReceiver,
    safeTransaction.nonce
  );
  await safe.contract.approveHash(txHash);
  const signature = generatePreValidatedSignature(safe.signer.address);
  addSignature(signature, safe.signer, safeTransaction);
}

function generatePreValidatedSignature(ownerAddress) {
  const signature =
    '0x000000000000000000000000' +
    ownerAddress.slice(2) +
    '0000000000000000000000000000000000000000000000000000000000000000' +
    '01'
  return signature;
}

function addSignature(signature, signer, safeTransaction) {
  safeTransaction.signatures.set(signer.address.toLowerCase(), signature)
}

function encodedSignatures(safeTransaction) {
  const signers = Array.from(safeTransaction.signatures.keys()).sort()
  let merge = ''
  signers.forEach((signerAddress) => {
    const signature = safeTransaction.signatures.get(signerAddress)
    merge += signature.slice(2)
  })
  return '0x' + merge
}

async function executeTransaction(safe, safeTransaction) {
  return await safe.contract.execTransaction(
    safeTransaction.to, safeTransaction.value, safeTransaction.data,
    safeTransaction.operation, safeTransaction.safeTxGas, safeTransaction.baseGas,
    safeTransaction.gasPrice, safeTransaction.gasToken, safeTransaction.refundReceiver,
    encodedSignatures(safeTransaction)
  );
}

async function executeMultisigTransaction(safeAddress, to, value, data) {
  const [deployer] = await ethers.getSigners();
  const safe = await createSafe(deployer, safeAddress);
  const owners = await safe.contract.getOwners();
  const threshold = await safe.contract.getThreshold();

  for (let i = 0; i < threshold; i ++) {
    await network.provider.request({method: "hardhat_impersonateAccount", params: [owners[i]]});
  }
  
  const safeTransaction = await createTransaction(safe, to, value, data);

  for (let i = 0; i < threshold; i ++) {
    let safe2 = await createSafe(await ethers.getSigner(owners[i]), safeAddress);
    await signTransaction(safe2, safeTransaction)
  }

  const tx = await executeTransaction(safe, safeTransaction);
  await tx.wait();
}

module.exports = {
  executeMultisigTransaction,
}