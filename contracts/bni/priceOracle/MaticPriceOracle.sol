//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./PriceOracle.sol";
import "../constant/MaticConstant.sol";

contract MaticPriceOracle is PriceOracle {

    function initialize() public virtual override initializer {
        super.initialize();

        address[] memory assets = new address[](2);
        assets[0] = MaticConstant.USDT;
        assets[1] = MaticConstant.WMATIC;
        address[] memory sources = new address[](2);
        sources[0] = 0x0A6513e40db6EB1b165753AD52E80663aeA50545;
        sources[1] = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;

        setAssetSources(assets, sources);
    }
}
