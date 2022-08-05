const { network } = require("hardhat");
const { parseEther } = require("ethers/lib/utils");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable").abi;

const { common } = require("../../parameters");
const { sendValue, etherBalance } = require("../../scripts/utils/ethereum");

module.exports = async () => {

  await network.provider.request({method: "hardhat_impersonateAccount", params: [common.admin]});

  const usdtHolder = await ethers.getSigner('0x52703b3930737d3C9E6Fb6E263747085e627B799');
  await network.provider.request({method: "hardhat_impersonateAccount", params: [usdtHolder.address]});
  const usdt = new ethers.Contract('0xc7198437980c041c805A1EDcbA50c1Ce5db95118', ERC20_ABI, usdtHolder);
  await usdt.transfer(deployer.address, await usdt.balanceOf(usdtHolder.address));

  const avalanchePoolAdmin = '0x2Ffc59d32A524611Bb891cab759112A51f9e33C0';
  await network.provider.request({method: "hardhat_impersonateAccount", params: [avalanchePoolAdmin]});

  const avaxHolder = '0x9f8c163cBA728e99993ABe7495F06c0A3c8Ac8b9';
  await network.provider.request({method: "hardhat_impersonateAccount", params: [avaxHolder]});
  await sendValue(avaxHolder, avalanchePoolAdmin, (await etherBalance(avaxHolder)).sub(parseEther('1')));
};

module.exports.tags = ["hardhat_avax_sti"];
module.exports.dependencies = [
  "hardhat_avax_reset",
  "avaxMainnet_bni_PriceOracle",
  "avaxMainnet_sti"
];
