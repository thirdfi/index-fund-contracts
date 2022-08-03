"use strict";
const { ethers } = require("hardhat")

async function rpc(request) {
  return ethers.provider.send(request.method, request.params);
}

async function mineBlock() {
    return rpc({ method: 'evm_mine' });
}
 
async function increaseTime(seconds) {
    await rpc({ method: 'evm_increaseTime', params: [seconds] });
    return rpc({ method: 'evm_mine' });
}

async function etherBalance(addr) {
  return (await ethers.provider.getBalance(addr));
}

async function sendEth(from, to, ethStr) {
    const value = ethers.utils.parseUnits(ethStr, 'ether').toHexString();
  
    const params = [{
      from: from,
      to: to,
      value: value.replace(/^0x0/, '0x')
    }];
    return await rpc({ method: 'eth_sendTransaction', params: params });
}

async function sendValue(from, to, amount) {
  const value = amount.toHexString()

  const params = [{
    from: from,
    to: to,
    value: value.replace(/^0x0/, '0x')
  }];
  return await rpc({ method: 'eth_sendTransaction', params: params });
}

module.exports = {
    mineBlock,
    increaseTime,
    etherBalance,
    sendEth,
    sendValue,
}