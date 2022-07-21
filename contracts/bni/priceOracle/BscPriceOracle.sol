//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./PriceOracle.sol";
import "../constant/BscConstant.sol";

contract BscPriceOracle is PriceOracle {

    function initialize() public virtual override initializer {
        super.initialize();

        address[] memory assets = new address[](3);
        assets[0] = BscConstant.USDC;
        assets[1] = BscConstant.USDT;
        assets[2] = BscConstant.WBNB;
        address[] memory sources = new address[](3);
        sources[0] = 0x51597f405303C4377E36123cBc172b13269EA163;
        sources[1] = 0xB97Ad0E74fa7d920791E90258A6E2085088b4320;
        sources[2] = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;

        setAssetSources(assets, sources);
    }

    function getAssetPrice(address asset) public virtual override view returns (uint price, uint8 decimals) {
        if (asset == address(0)) {
            asset = BscConstant.WBNB;
        }
        return super.getAssetPrice(asset);
    }
}
