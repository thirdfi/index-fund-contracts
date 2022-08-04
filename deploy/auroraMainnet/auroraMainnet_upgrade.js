module.exports = async () => {
};
module.exports.tags = ["auroraMainnet_upgrade"];
module.exports.dependencies = [
  "auroraMainnet_bni_BNIStrategy", // AuroraBNIStrategy
  "auroraMainnet_bni_PriceOracle", // BasicCompoundVault
  "auroraMainnet_l2_upgrade_BastionVaults", // BasicCompoundVault
];
