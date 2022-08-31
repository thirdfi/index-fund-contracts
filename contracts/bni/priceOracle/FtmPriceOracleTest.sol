//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./FtmPriceOracle.sol";
import "../constant/FtmConstantTest.sol";
import "../../../libs/Const.sol";

contract FtmPriceOracleTest is FtmPriceOracle {

    function initialize() public override initializer {
        super.initialize();

        address[] memory assets = new address[](2);
        assets[0] = FtmConstantTest.USDT;
        assets[1] = FtmConstantTest.WFTM;
        address[] memory sources = new address[](2);
        sources[0] = 0x9BB8A6dcD83E36726Cc230a97F1AF8a84ae5F128;
        sources[1] = 0xe04676B9A9A2973BCb0D1478b5E1E9098BBB7f3D;

        setAssetSources(assets, sources);
    }

    function getAssetPrice(address asset) public override view returns (uint price, uint8 decimals) {
        if (asset == Const.NATIVE_ASSET) {
            asset = FtmConstantTest.WFTM;
        }
        return super.getAssetPrice(asset);
    }
}
