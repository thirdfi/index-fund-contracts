//SPDX-License-Identifier: MIT
//
///@notice The AvaxStAVAXVault contract stakes AVAX tokens into aAVAXb on Avalanche.
///@dev https://www.ankr.com/docs/staking/liquid-staking/avax/staking-mechanics
//
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "./AvaxStAVAXVault.sol";
import "../../bni/constant/AvaxConstantTest.sol";
import "../../../libs/Const.sol";

contract AvaxStAVAXVaultTest is AvaxStAVAXVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize1(
        address _treasury, address _admin,
        address _priceOracle
    ) public override initializer {
        super.initialize(
            "STI Staking AVAX", "stiStAVAX",
            _treasury, _admin,
            _priceOracle,
            Const.NATIVE_ASSET, // AVAX
            AvaxConstantTest.aAVAXb
        );

        avalanchePool = IAvalanchePool(0x0C29D40cBD3c9073f4C0c96Bf88Ae1B4b4FE1d11);

        unbondingPeriod = 28 days;
        minInvestAmount = avalanchePool.getMinimumStake();
        oneEpoch = 24 hours;

        stToken.safeApprove(address(avalanchePool), type(uint).max);
    }
}
