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

    IBinancePool public constant binancePool = IBinancePool(0x66BEA595AEFD5a65799a920974b377Ed20071118);
    uint256 constant TEN_DECIMALS = 1e10;

    function initialize1(
        address _treasury, address _admin,
        address _priceOracle
    ) public initializer {
        super.initialize(
            "STI Staking BNB", "stiStBNB",
            _treasury, _admin,
            _priceOracle,
            Const.NATIVE_ASSET, // BNB
            BscConstant.aBNBb
        );

        unbondingPeriod = 14 days;
        minInvestAmount = oneToken * 1002 / 1000;
        minRedeemAmount = oneStToken;
        oneEpoch = 24 hours;

        stToken.safeApprove(address(binancePool), type(uint).max);
    }

    function _invest(uint _amount) internal override returns (uint _invested) {
        _amount -= (_amount % TEN_DECIMALS); // To avoid the error of "invalid received BNB amount: precision loss in amount conversion" in TokenHub.transferOut()
        binancePool.stakeAndClaimBonds{value: _amount}();
        return _amount;
    }

    function _redeem(uint _stAmount) internal override returns (uint _redeemed) {
        // Because _stAmount-stBalance may be a calculation delta in withdraw function,
        // it will reduce the pendingRedeems even though no redeeming on the staking pool.
        _redeemed = _stAmount;

        uint stBalance = stToken.balanceOf(address(this));
        if (stBalance > 0) {
            binancePool.unstakeBonds(_stAmount > stBalance ? stBalance : _stAmount);
        }
    }

    function getEmergencyUnbondings() public override view returns (uint) {
        // binancePool automatically transfers the unbonded BNB to the claimer. This is why there is no _claimUnbonded here
        uint unbondings = binancePool.pendingUnstakesOf(address(this));
        return MathUpgradeable.min(unbondings, emergencyUnbondings);
    }

    function _emergencyWithdraw(uint _pendingRedeems) internal override returns (uint _redeemed) {
        uint stBalance = stToken.balanceOf(address(this));
        if (stBalance >= minRedeemAmount) {
            binancePool.unstakeBonds(stBalance);
            emergencyUnbondings = (stBalance > _pendingRedeems) ? stBalance - _pendingRedeems : 0;
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
