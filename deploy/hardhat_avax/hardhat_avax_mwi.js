const { network } = require("hardhat");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable").abi;

const { common } = require("../../parameters");

module.exports = async () => {
  const [deployer] = await ethers.getSigners();

  await network.provider.request({method: "hardhat_impersonateAccount", params: [common.admin]});

  await network.provider.request({method: "hardhat_impersonateAccount", params: ['0x52703b3930737d3C9E6Fb6E263747085e627B799']});
  const usdtHolder = await ethers.getSigner('0x52703b3930737d3C9E6Fb6E263747085e627B799');
  const usdt = new ethers.Contract('0xc7198437980c041c805A1EDcbA50c1Ce5db95118', ERC20_ABI, usdtHolder);
  await usdt.transfer(deployer.address, await usdt.balanceOf(usdtHolder.address));
};

module.exports.tags = ["hardhat_avax_mwi"];
module.exports.dependencies = [
  "hardhat_avax_reset",
  "avaxMainnet_mwi"
];
