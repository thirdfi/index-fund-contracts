//SPDX-License-Identifier: MIT
//
///@notice The AuroraStNEARVault contract stakes wNEAR tokens into stNEAR on Aurora.
///@dev https://metapool.gitbook.io/master/developers-1/contract-adresses
///@dev https://metapool.app/dapp/mainnet/metapool-aurora/
//
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "./AuroraStNEARVault.sol";
import "../../bni/constant/AuroraConstantTest.sol";
import "../../../interfaces/IL2Vault.sol";
import "../../../libs/Token.sol";

contract AuroraStNEARVaultTest is AuroraStNEARVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize1(
        address _treasury, address _admin,
        address _priceOracle,
        IL2Vault _stNEARVault
    ) public override initializer {
        super.initialize(
            "STI Staking WNEAR", "stiStNEAR",
            _treasury, _admin,
            _priceOracle,
            AuroraConstantTest.WNEAR,
            AuroraConstantTest.stNEAR
        );

        metaPool = IMetaPool(0x0dF588AabDd4E031f1903326cC0d8E79DFBD3566);

        // The backend will call redeem per 1 hour.
        unbondingPeriod = 1 hours;
        minInvestAmount = oneToken;
        // The stNEAR buffer is replenished automatically every 5 minutes.
        investInterval = 5 minutes;
        // The wNEAR buffer is replenished automatically every 5 minutes.
        redeemInterval = 5 minutes;
        oneEpoch = 12 hours;

        stNEARVault = _stNEARVault;

        token.safeApprove(address(metaPool), type(uint).max);
        stToken.safeApprove(address(metaPool), type(uint).max);
        stToken.safeApprove(address(stNEARVault), type(uint).max);
    }
}
