module.exports = async () => {
};
module.exports.tags = ["auroraMainnet_bni2"];
module.exports.dependencies = [
  "auroraMainnet_bni_PriceOracle", // Upgrade PriceOracle
  "auroraMainnet_l2_BastionFactory",
  "auroraMainnet_l2_BastionVaults",
  "auroraMainnet_bni_BNIStrategy", // Upgrade BNIStrategy
];
