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

module.exports = {
    mineBlock,
    increaseTime,
}