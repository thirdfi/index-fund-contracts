//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./BscPriceOracle.sol";
import "../constant/BscConstantTest.sol";
import "../../../libs/Const.sol";

contract BscPriceOracleTest is BscPriceOracle {

    function initialize() public override initializer {
        super.initialize();

        address[] memory assets = new address[](5);
        assets[0] = BscConstantTest.USDC;
        assets[1] = BscConstantTest.USDT;
        assets[2] = BscConstantTest.WBNB;
        assets[3] = BscConstantTest.CAKE;
        assets[4] = BscConstantTest.BUSD;
        address[] memory sources = new address[](5);
        sources[0] = 0x90c069C4538adAc136E051052E14c1cD799C41B7;
        sources[1] = 0xEca2605f0BCF2BA5966372C99837b1F182d3D620;
        sources[2] = 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526;
        sources[3] = 0x81faeDDfeBc2F8Ac524327d70Cf913001732224C;
        sources[4] = 0x9331b55D9830EF609A2aBCfAc0FBCE050A52fdEa;

        setAssetSources(assets, sources);
    }

    function getAssetPrice(address asset) public override view returns (uint price, uint8 decimals) {
        if (asset == Const.NATIVE_ASSET) {
            asset = BscConstantTest.WBNB;
        }
        return super.getAssetPrice(asset);
    }
}
