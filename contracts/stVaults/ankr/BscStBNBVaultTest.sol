//SPDX-License-Identifier: MIT
//
///@notice The AvaxStAVAXVault contract stakes AVAX tokens into aAVAXb on Avalanche.
///@dev https://www.ankr.com/docs/staking/liquid-staking/avax/staking-mechanics
//
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "./BscStBNBVault.sol";
import "../../bni/constant/BscConstantTest.sol";
import "../../../libs/Const.sol";

contract BscStBNBVaultTest is BscStBNBVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize1(
        address _treasury, address _admin,
        address _priceOracle
    ) public override initializer {
        super.initialize(
            "STI Staking BNB", "stiStBNB",
            _treasury, _admin,
            _priceOracle,
            Const.NATIVE_ASSET, // BNB
            BscConstantTest.aBNBb
        );

        binancePool = IBinancePool(0x3C9205b5d4B312cA7C4d28110C91Fe2c74718a94);

        unbondingPeriod = 14 days;
        minInvestAmount = oneToken * 1002 / 1000;
        minRedeemAmount = oneStToken;
        oneEpoch = 24 hours;

        stToken.safeApprove(address(binancePool), type(uint).max);
    }
}
