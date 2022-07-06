module.exports = async () => {
};
module.exports.tags = ["auroraTestnet_bni2"];
module.exports.dependencies = [
  "auroraTestnet_bni_PriceOracle", // Upgrade PriceOracle
  "auroraTestnet_l2_BastionFactory",
  "auroraTestnet_l2_BastionVaults",
];
