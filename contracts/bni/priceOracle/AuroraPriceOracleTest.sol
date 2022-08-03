//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./AuroraPriceOracle.sol";
import "../constant/AuroraConstantTest.sol";
import "../../../libs/Const.sol";

contract AuroraPriceOracleTest is AuroraPriceOracle {

    ///@notice Chainlink is not yet supported on Aurora.
    function getAssetPrice(address asset) public override view returns (uint price, uint8 decimals) {
        if (asset == AuroraConstantTest.USDT || asset == AuroraConstantTest.USDC) {
            return (1e8, 8);
        } else if (asset == AuroraConstantTest.WNEAR) {
            return getWNEARPrice();
        } else if (asset == AuroraConstantTest.BSTN) {
            return (34e14, 18);
        } else if (asset == AuroraConstantTest.META) {
            return (1e16, 18);
        } else if (asset == AuroraConstantTest.stNEAR) {
            return getStNEARPrice();
        }
        return super.getAssetPrice(asset);
    }

    function getWNEARPrice() public view override returns (uint price, uint8 decimals) {
        return (423e16, 18);
    }
}