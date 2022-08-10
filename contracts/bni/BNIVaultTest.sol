 // SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./priceOracle/IPriceOracle.sol";
import "./BNIVault.sol";

contract BNIVaultTest is BNIVault {

    function setPriceOracle(address _priceOracle) external onlyOwner {
        priceOracle = IPriceOracle(_priceOracle);
    }
}
