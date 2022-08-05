//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./MaticPriceOracle.sol";
import "../constant/MaticConstantTest.sol";

contract MaticPriceOracleTest is MaticPriceOracle {

    function initialize() public override initializer {
        super.initialize();

        address[] memory assets = new address[](3);
        assets[0] = MaticConstantTest.USDT;
        assets[1] = MaticConstantTest.WMATIC;
        assets[2] = MaticConstantTest.USDC;
        address[] memory sources = new address[](3);
        sources[0] = 0x92C09849638959196E976289418e5973CC96d645;
        sources[1] = 0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada;
        sources[2] = 0x572dDec9087154dC5dfBB1546Bb62713147e0Ab0;

        setAssetSources(assets, sources);
    }

    function getAssetPrice(address asset) public override view returns (uint price, uint8 decimals) {
        if (asset == Const.NATIVE_ASSET) {
            asset = MaticConstantTest.WMATIC;
        }
        return super.getAssetPrice(asset);
    }
}
