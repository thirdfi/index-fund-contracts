//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./PriceOracle.sol";
import "../constant/EthConstant.sol";

contract EthPriceOracle is PriceOracle {

    function initialize() public virtual override initializer {
        super.initialize();

        address[] memory assets = new address[](2);
        assets[0] = EthConstant.USDT;
        assets[1] = EthConstant.MATIC;
        assets[2] = EthConstant.WETH;
        address[] memory sources = new address[](2);
        sources[0] = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
        sources[1] = 0x7bAC85A8a13A4BcD8abb3eB7d6b4d632c5a57676;
        sources[1] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

        setAssetSources(assets, sources);
    }

    function getAssetPrice(address asset) public virtual override view returns (uint price, uint8 decimals) {
        if (asset == address(0)) {
            asset = EthConstant.WETH;
        }
        return super.getAssetPrice(asset);
    }

}
