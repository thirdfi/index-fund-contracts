//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./PriceOracle.sol";
import "../constant/MoonbeamConstant.sol";
import "../../../libs/Const.sol";

contract MoonbeamPriceOracle is PriceOracle {

    function initialize() public virtual override initializer {
        super.initialize();

        address[] memory assets = new address[](3);
        assets[0] = MoonbeamConstant.WGLMR;
        assets[1] = MoonbeamConstant.USDC_mad;
        assets[2] = MoonbeamConstant.xcDOT;
        address[] memory sources = new address[](3);
        sources[0] = 0x4497B606be93e773bbA5eaCFCb2ac5E2214220Eb;
        sources[1] = 0xA122591F60115D63421f66F752EF9f6e0bc73abC;
        sources[2] = 0x1466b4bD0C4B6B8e1164991909961e0EE6a66d8c;

        setAssetSources(assets, sources);
    }

    function getAssetPrice(address asset) public virtual override view returns (uint price, uint8 decimals) {
        if (asset == Const.NATIVE_ASSET) {
            asset = MoonbeamConstant.WGLMR;
        } else if (asset == MoonbeamConstant.USDT_mad) {
            return (1e8, 8);
        }
        return super.getAssetPrice(asset);
    }
}
