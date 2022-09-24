// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./BNIMinter.sol";
import "./priceOracle/IPriceOracle.sol";
import "./constant/AvaxConstantTest.sol";
import "./constant/AuroraConstantTest.sol";
import "./constant/MaticConstantTest.sol";

contract BNIMinterTest is BNIMinter {

    function initialize(
        address _admin, address _BNI, address _priceOracle
    ) public override initializer {
        super.initialize(_admin, _BNI, _priceOracle);

        relpaceTokens();
    }

    /// @return the price of USDT in USD.
    function getUSDTPriceInUSD() public override view returns(uint, uint8) {
        return priceOracle.getAssetPrice(AvaxConstantTest.USDT);
    }

    function setPriceOracle(address _priceOracle) external onlyOwner {
        priceOracle = IPriceOracle(_priceOracle);
    }

    function relpaceTokens() public onlyOwner {
        chainIDs.pop();
        chainIDs.pop();
        chainIDs.pop();
        chainIDs.push(MaticConstantTest.CHAINID);
        chainIDs.push(AvaxConstantTest.CHAINID);
        chainIDs.push(AuroraConstantTest.CHAINID);

        tokens.pop();
        tokens.pop();
        tokens.pop();
        tokens.push(MaticConstantTest.WMATIC);
        tokens.push(AvaxConstantTest.WAVAX);
        tokens.push(AuroraConstantTest.WNEAR);
    }
}
