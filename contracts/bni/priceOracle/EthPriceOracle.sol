//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./PriceOracle.sol";
import "../constant/EthConstant.sol";
import "../../../libs/Const.sol";

contract EthPriceOracle is PriceOracle {

    function initialize() public virtual override initializer {
        super.initialize();

        address[] memory assets = new address[](4);
        assets[0] = EthConstant.USDT;
        assets[1] = EthConstant.MATIC;
        assets[2] = EthConstant.WETH;
        assets[3] = EthConstant.USDC;
        address[] memory sources = new address[](4);
        sources[0] = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
        sources[1] = 0x7bAC85A8a13A4BcD8abb3eB7d6b4d632c5a57676;
        sources[2] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        sources[3] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

        setAssetSources(assets, sources);
    }

    function getAssetPrice(address asset) public virtual override view returns (uint price, uint8 decimals) {
        if (asset == Const.NATIVE_ASSET) {
            asset = EthConstant.WETH;
        }
        return super.getAssetPrice(asset);
    }

}
