module.exports = async () => {
};
module.exports.tags = ["auroraMainnet_sti"];
module.exports.dependencies = [
  "auroraMainnet_bni_PriceOracle", // Upgrade PriceOracle
  "auroraMainnet_l2_upgrade_BastionVaults", // Upgrade AuroraBastionVault
  "common_sti_StVaultNFTFactory",
  "auroraMainnet_sti_StNEAR",
  "auroraMainnet_sti_STIStrategy",
  "auroraMainnet_sti_STIVault",
];
