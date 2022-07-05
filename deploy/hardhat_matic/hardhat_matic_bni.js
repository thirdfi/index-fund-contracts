const { network } = require("hardhat");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable").abi;

const { common } = require("../../parameters");

module.exports = async () => {

  await network.provider.request({method: "hardhat_impersonateAccount", params: [common.admin]});

  await network.provider.request({method: "hardhat_impersonateAccount", params: ['0xe7804c37c13166fF0b37F5aE0BB07A3aEbb6e245']});
  const usdtHolder = await ethers.getSigner('0xe7804c37c13166fF0b37F5aE0BB07A3aEbb6e245');
  const usdt = new ethers.Contract('0xc2132D05D31c914a87C6611C10748AEb04B58e8F', ERC20_ABI, usdtHolder);
  await usdt.transfer(deployer.address, await usdt.balanceOf(usdtHolder.address));
};

module.exports.tags = ["hardhat_matic_bni"];
module.exports.dependencies = [
  "hardhat_matic_reset",
  "maticMainnet_bni_PriceOracle",
  "maticMainnet_bni2",
  "maticMainnet_bni_BNIVault",
];
