//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./AuroraPriceOracle.sol";
import "../constant/AuroraConstantTest.sol";
import "../../../libs/Const.sol";

contract AuroraPriceOracleTest is AuroraPriceOracle {

    IMetaPool constant metaPoolTest = IMetaPool(0x0dF588AabDd4E031f1903326cC0d8E79DFBD3566);

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

    function getStNEARPrice() internal view override returns (uint price, uint8 decimals) {
        uint wNearAmount = metaPoolTest.stNearPrice() * (Const.DENOMINATOR - metaPoolTest.wNearSwapFee()) / Const.DENOMINATOR;
        (uint WNEARPriceInUSD, uint8 WNEARPriceDecimals) = getWNEARPrice();
        price = WNEARPriceInUSD * wNearAmount / 1e24; // WNEAR decimals is 24;
        decimals = WNEARPriceDecimals;
    }
}