//SPDX-License-Identifier: MIT
//
///@notice The AvaxStAVAXVault contract stakes AVAX tokens into aAVAXb on Avalanche.
///@dev https://www.ankr.com/docs/staking/liquid-staking/avax/staking-mechanics
//
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "../BasicStVault.sol";
import "../../bni/constant/BscConstant.sol";
import "../../../libs/Const.sol";

interface IBinancePool {
    function stakeAndClaimBonds() external payable;
    function stakeAndClaimCerts() external payable;
    function pendingUnstakesOf(address claimer) external view returns (uint);
    function unstakeBonds(uint amount) external;
    function unstakeCerts(uint shares) external;
}

interface IABNBb {
    function ratio() external view returns (uint);
    function bondsToShares(uint amount) external view returns (uint);
    function sharesToBonds(uint amount) external view returns (uint);
}

contract BscStBNBVault is BasicStVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IBinancePool public binancePool = IBinancePool(0x66BEA595AEFD5a65799a920974b377Ed20071118);

    function initialize(
        address _treasury, address _admin,
        address _priceOracle
    ) public initializer {
        super.initialize(
            "STI L2 stBNB", "stiL2StBNB",
            _treasury, _admin,
            _priceOracle,
            Const.NATIVE_ASSET, // BNB
            BscConstant.aBNBb
        );

        unbondingPeriod = 14 days;
        minInvestAmount = oneToken * 1002 / 1000;
        minRedeemAmount = oneStToken;
        oneEpoch = 24 hours;
    }

    function _invest(uint _amount) internal override returns (uint _invested) {
        binancePool.stakeAndClaimBonds{value: _amount}();
        return _amount;
    }

    function _redeem(uint _stAmount) internal override returns (uint _redeemed) {
        binancePool.unstakeBonds(_stAmount);
        return _stAmount;
    }

    function getEmergencyUnbondings() public override view returns (uint) {
        // The unbonded AVAX is automatically transferred to the claimer. This is why there is no _claimUnbonded here
        uint unbondings = binancePool.pendingUnstakesOf(address(this));
        return MathUpgradeable.min(unbondings, emergencyUnbondings);
    }

    function _emergencyWithdraw(uint _pendingRedeems) internal override returns (uint _redeemed) {
        uint stBalance = stToken.balanceOf(address(this));
        if (stBalance >= minRedeemAmount) {
            binancePool.unstakeBonds(stBalance);
            emergencyUnbondings = (stBalance - _pendingRedeems);
            _redeemed = stBalance;
        }
    }

    ///@param _amount Amount of tokens
    function getStTokenByPooledToken(uint _amount) public override view returns(uint) {
        return _amount * IABNBb(address(stToken)).ratio() / 1e18;
    }

    ///@param _stAmount Amount of stTokens
    function getPooledTokenByStToken(uint _stAmount) public override view returns(uint) {
        return _stAmount * 1e18 / IABNBb(address(stToken)).ratio();
    }
}
