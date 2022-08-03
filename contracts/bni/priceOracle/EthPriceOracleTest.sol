//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "./EthPriceOracle.sol";
import "../constant/EthConstantTest.sol";
import "../../../libs/Const.sol";

contract EthPriceOracleTest is EthPriceOracle {

    function initialize() public override initializer {
        super.initialize();

        address[] memory assets = new address[](4);
        assets[0] = EthConstantTest.USDT;
        assets[1] = EthConstantTest.MATIC;
        assets[2] = EthConstantTest.WETH;
        assets[3] = EthConstantTest.USDC;
        address[] memory sources = new address[](4);
        sources[0] = 0xa24de01df22b63d23Ebc1882a5E3d4ec0d907bFB;
        sources[1] = 0x7794ee502922e2b723432DDD852B3C30A911F021;
        sources[2] = 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e;
        sources[3] = 0xa24de01df22b63d23Ebc1882a5E3d4ec0d907bFB;

        setAssetSources(assets, sources);
    }

    function getAssetPrice(address asset) public virtual override view returns (uint price, uint8 decimals) {
        if (asset == Const.NATIVE_ASSET) {
            asset = EthConstantTest.WETH;
        }
        return super.getAssetPrice(asset);
    }

}
