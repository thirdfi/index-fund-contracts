//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./PriceOracle.sol";
import "../constant/AvaxConstant.sol";
import "../../../libs/Const.sol";

contract AvaxPriceOracle is PriceOracle {

    function initialize() public virtual override initializer {
        super.initialize();

        address[] memory assets = new address[](2);
        assets[0] = AvaxConstant.USDT;
        assets[1] = AvaxConstant.WAVAX;
        address[] memory sources = new address[](2);
        sources[0] = 0xEBE676ee90Fe1112671f19b6B7459bC678B67e8a;
        sources[1] = 0x0A77230d17318075983913bC2145DB16C7366156;

        setAssetSources(assets, sources);
    }

    function getAssetPrice(address asset) public virtual override view returns (uint price, uint8 decimals) {
        if (asset == Const.NATIVE_ASSET) {
            asset = AvaxConstant.WAVAX;
        }
        return super.getAssetPrice(asset);
    }
}
