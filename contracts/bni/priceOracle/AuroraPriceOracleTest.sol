//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./AuroraPriceOracle.sol";
import "../constant/AuroraConstant.sol";
import "../../../libs/Const.sol";

contract AuroraPriceOracleTest is AuroraPriceOracle {

    ///@notice Chainlink is not yet supported on Aurora.
    function getAssetPrice(address asset) public virtual override view returns (uint price, uint8 decimals) {
        if (asset == AuroraConstant.USDT || asset == AuroraConstant.USDC) {
            return (1e8, 8);
        } else if (asset == AuroraConstant.WNEAR) {
            return getWNEARPrice();
        } else if (asset == AuroraConstant.BSTN) {
            return (34e14, 18);
        } else if (asset == AuroraConstant.META) {
            return (1e16, 18);
        } else if (asset == AuroraConstant.stNEAR) {
            return getStNEARPrice();
        }
        return super.getAssetPrice(asset);
    }

    function getWNEARPrice() public view override returns (uint price, uint8 decimals) {
        return (423e16, 18);
    }
}