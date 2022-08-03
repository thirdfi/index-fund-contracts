//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./AvaxPriceOracle.sol";
import "../constant/AvaxConstantTest.sol";
import "../../../libs/Const.sol";

contract AvaxPriceOracleTest is AvaxPriceOracle {

    function initialize() public override initializer {
        super.initialize();

        address[] memory assets = new address[](2);
        assets[0] = AvaxConstantTest.USDT;
        assets[1] = AvaxConstantTest.WAVAX;
        address[] memory sources = new address[](2);
        sources[0] = 0x7898AcCC83587C3C55116c5230C17a6Cd9C71bad;
        sources[1] = 0x5498BB86BC934c8D34FDA08E81D444153d0D06aD;

        setAssetSources(assets, sources);
    }

    function getAssetPrice(address asset) public virtual override view returns (uint price, uint8 decimals) {
        if (asset == Const.NATIVE_ASSET) {
            asset = AvaxConstantTest.WAVAX;
        }
        return super.getAssetPrice(asset);
    }
}
