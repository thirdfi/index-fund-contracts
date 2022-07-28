//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./PriceOracle.sol";
import "../constant/BscConstant.sol";
import "../../../libs/Const.sol";

contract BscPriceOracle is PriceOracle {

    function initialize() public virtual override initializer {
        super.initialize();

        address[] memory assets = new address[](5);
        assets[0] = BscConstant.USDC;
        assets[1] = BscConstant.USDT;
        assets[2] = BscConstant.WBNB;
        assets[3] = BscConstant.CAKE;
        assets[4] = BscConstant.BUSD;
        address[] memory sources = new address[](5);
        sources[0] = 0x51597f405303C4377E36123cBc172b13269EA163;
        sources[1] = 0xB97Ad0E74fa7d920791E90258A6E2085088b4320;
        sources[2] = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;
        sources[3] = 0xB6064eD41d4f67e353768aA239cA86f4F73665a1;
        sources[4] = 0xcBb98864Ef56E9042e7d2efef76141f15731B82f;

        setAssetSources(assets, sources);
    }

    function getAssetPrice(address asset) public virtual override view returns (uint price, uint8 decimals) {
        if (asset == Const.NATIVE_ASSET) {
            asset = BscConstant.WBNB;
        }
        return super.getAssetPrice(asset);
    }
}
