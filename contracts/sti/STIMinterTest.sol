// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./STIMinter.sol";
import "../bni/priceOracle/IPriceOracle.sol";
import "../bni/constant/AuroraConstantTest.sol";
import "../bni/constant/AvaxConstantTest.sol";
import "../bni/constant/BscConstantTest.sol";
import "../bni/constant/EthConstantTest.sol";
import "../../libs/Const.sol";

contract STIMinterTest is STIMinter {

    function initialize(
        address _admin, address _userAgent, address _biconomy,
        address _STI, address _priceOracle
    ) external override initializer {
        __Ownable_init();
        address _owner = owner();
        admin = _admin;
        userAgent = _userAgent;

        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(ADMIN_ROLE, _admin);
        _setupRole(ADMIN_ROLE, _userAgent);

        trustedForwarder = _biconomy;
        STI = ISTI(_STI);
        priceOracle = IPriceOracle(_priceOracle);

        chainIDs.push(EthConstantTest.CHAINID);
        tokens.push(Const.NATIVE_ASSET); // ETH
        chainIDs.push(EthConstantTest.CHAINID);
        tokens.push(EthConstantTest.MATIC);
        chainIDs.push(BscConstantTest.CHAINID);
        tokens.push(Const.NATIVE_ASSET); // BNB
        chainIDs.push(AvaxConstantTest.CHAINID);
        tokens.push(Const.NATIVE_ASSET); // AVAX
        chainIDs.push(AuroraConstantTest.CHAINID);
        tokens.push(AuroraConstantTest.WNEAR);

        targetPercentages.push(2000); // 20%
        targetPercentages.push(2000); // 20%
        targetPercentages.push(2000); // 20%
        targetPercentages.push(2000); // 20%
        targetPercentages.push(2000); // 20%

        updateTid();

        urls.push("http://localhost:8001/");
        gatewaySigner = _admin;
    }

    /// @return the price of USDT in USD.
    function getUSDTPriceInUSD() public view override returns(uint, uint8) {
        return priceOracle.getAssetPrice(EthConstantTest.USDT);
    }
}
