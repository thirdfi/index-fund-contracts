const { network } = require("hardhat");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable").abi;

const { common } = require("../../parameters");

module.exports = async () => {
  const [deployer] = await ethers.getSigners();

  await network.provider.request({method: "hardhat_impersonateAccount", params: [common.admin]});

  await network.provider.request({method: "hardhat_impersonateAccount", params: ['0x3DCa07E16B2Becd3eb76a9F9CE240B525451f887']});
  const usdtHolder = await ethers.getSigner('0x3DCa07E16B2Becd3eb76a9F9CE240B525451f887');
  const usdt = new ethers.Contract('0x4988a896b1227218e4A686fdE5EabdcAbd91571f', ERC20_ABI, usdtHolder);
  await usdt.transfer(deployer.address, await usdt.balanceOf(usdtHolder.address));
};

module.exports.tags = ["hardhat_aurora_bni"];
module.exports.dependencies = [
  "hardhat_aurora_reset",
  "auroraMainnet_bni",
  "auroraMainnet_bni2",
];
