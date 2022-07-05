const { network } = require("hardhat");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable").abi;

const { common } = require("../../parameters");

module.exports = async () => {

  await network.provider.request({method: "hardhat_impersonateAccount", params: [common.admin]});

  await network.provider.request({method: "hardhat_impersonateAccount", params: ['0x52703b3930737d3C9E6Fb6E263747085e627B799']});
  const usdtHolder = await ethers.getSigner('0x52703b3930737d3C9E6Fb6E263747085e627B799');
  const usdt = new ethers.Contract('0xc7198437980c041c805A1EDcbA50c1Ce5db95118', ERC20_ABI, usdtHolder);
  await usdt.transfer(deployer.address, await usdt.balanceOf(usdtHolder.address));
};

module.exports.tags = ["hardhat_avax_bni"];
module.exports.dependencies = [
  "hardhat_avax_reset",
  "avaxMainnet_mwi_L2Factory",
  "avaxMainnet_mwi_L2Vaults",
  "avaxMainnet_bni_PriceOracle",
  "avaxMainnet_bni_BNI",
  "avaxMainnet_bni_BNIMinter",
  "avaxMainnet_bni2",
  "avaxMainnet_bni_BNIVault",
];
