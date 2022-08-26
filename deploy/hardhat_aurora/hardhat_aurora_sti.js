const { network } = require("hardhat");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable").abi;

const { common } = require("../../parameters");

module.exports = async () => {

  await network.provider.request({method: "hardhat_impersonateAccount", params: [common.admin]});

  const usdtHolder = await ethers.getSigner('0x92D385172c6eC14ED5a670A8148db3fD70F62A40');
  await network.provider.request({method: "hardhat_impersonateAccount", params: [usdtHolder.address]});
  const usdt = new ethers.Contract('0x4988a896b1227218e4A686fdE5EabdcAbd91571f', ERC20_ABI, usdtHolder);
  await usdt.transfer(deployer.address, await usdt.balanceOf(usdtHolder.address));

  const metaPoolAdmin = await ethers.getSigner('0x37a86c3Ec281A70Da4d438e2D744137850Ff8E7b');
  await network.provider.request({method: "hardhat_impersonateAccount", params: [metaPoolAdmin.address]});
};

module.exports.tags = ["hardhat_aurora_sti"];
module.exports.dependencies = [
  "hardhat_aurora_reset",
  "auroraMainnet_xchain",
  "auroraMainnet_l2_BastionFactory",
  "auroraMainnet_bni_PriceOracle",
  "auroraMainnet_sti",
];
