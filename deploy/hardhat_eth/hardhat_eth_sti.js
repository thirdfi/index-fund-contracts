const { network } = require("hardhat");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable").abi;

const { common } = require("../../parameters");

module.exports = async () => {

  await network.provider.request({method: "hardhat_impersonateAccount", params: [common.admin]});

  const usdtHolder = await ethers.getSigner('0x5a52E96BAcdaBb82fd05763E25335261B270Efcb');
  await network.provider.request({method: "hardhat_impersonateAccount", params: [usdtHolder.address]});
  const usdt = new ethers.Contract('0xdAC17F958D2ee523a2206206994597C13D831ec7', ERC20_ABI, usdtHolder);
  await usdt.transfer(deployer.address, await usdt.balanceOf(usdtHolder.address));

  const maticHolder = await ethers.getSigner('0xF977814e90dA44bFA03b6295A0616a897441aceC');
  await network.provider.request({method: "hardhat_impersonateAccount", params: [maticHolder.address]});
  const matic = new ethers.Contract('0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0', ERC20_ABI, maticHolder);
  await matic.transfer(deployer.address, await matic.balanceOf(maticHolder.address));
};

module.exports.tags = ["hardhat_eth_sti"];
module.exports.dependencies = [
  "hardhat_eth_reset",
  "ethMainnet_sti"
];
