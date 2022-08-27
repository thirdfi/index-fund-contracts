const { network } = require("hardhat");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable").abi;

const { common } = require("../../parameters");

module.exports = async () => {
  const [deployer] = await ethers.getSigners();

  await network.provider.request({method: "hardhat_impersonateAccount", params: [common.admin]});

  await network.provider.request({method: "hardhat_impersonateAccount", params: ['0xF977814e90dA44bFA03b6295A0616a897441aceC']});
  const usdtHolder = await ethers.getSigner('0xF977814e90dA44bFA03b6295A0616a897441aceC');
  const usdt = new ethers.Contract('0x55d398326f99059fF775485246999027B3197955', ERC20_ABI, usdtHolder);
  await usdt.transfer(deployer.address, await usdt.balanceOf(usdtHolder.address));
};

module.exports.tags = ["hardhat_bsc_lci"];
module.exports.dependencies = [
  "hardhat_bsc_reset",
  "bscMainnet_lci"
];
