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
import "../../bni/constant/AvaxConstant.sol";
import "../../../libs/Const.sol";

interface IAvalanchePool {
    function stakeAndClaimBonds() external payable;
    function stakeAndClaimCerts() external payable;
    function pendingAvaxClaimsOf(address claimer) external view returns (uint);
    function claimBonds(uint amount) external;
    function claimCerts(uint amount) external;
    function getMinimumStake() external view returns (uint);
}

interface IAAVAXb {
    function ratio() external view returns (uint);
    function sharesToBalance(uint amount) external view returns (uint);
}

contract AvaxStAVAXVault is BasicStVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IAvalanchePool public avalanchePool;

    function initialize1(
        address _treasury, address _admin,
        address _priceOracle
    ) public virtual initializer {
        super.initialize(
            "STI Staking AVAX", "stiStAVAX",
            _treasury, _admin,
            _priceOracle,
            Const.NATIVE_ASSET, // AVAX
            AvaxConstant.aAVAXb
        );

        avalanchePool = IAvalanchePool(0x7BAa1E3bFe49db8361680785182B80BB420A836D);

        unbondingPeriod = 28 days;
        minInvestAmount = avalanchePool.getMinimumStake();
        oneEpoch = 24 hours;

        stToken.safeApprove(address(avalanchePool), type(uint).max);
    }

    function setStakingAmounts(uint _minInvestAmount, uint _minRedeemAmount) external override onlyOwner {
        _minInvestAmount;
        require(_minRedeemAmount > 0, "minRedeemAmount must be > 0");
        minInvestAmount = avalanchePool.getMinimumStake();
        minRedeemAmount = _minRedeemAmount;
    }

    function _invest(uint _amount) internal override returns (uint _invested) {
        _invested = _amount - (_amount % minInvestAmount); // Value must be multiple of minimum staking amount
        if (_invested > 0) {
            avalanchePool.stakeAndClaimBonds{value: _invested}();
        }
    }

    function _redeem(uint _stAmount) internal override returns (uint _redeemed) {
        // Because _stAmount-stBalance may be a calculation delta in withdraw function,
        // it will reduce the pendingRedeems even though no redeeming on the staking pool.
        _redeemed = _stAmount;

        uint stBalance = stToken.balanceOf(address(this));
        if (stBalance > 0) {
            avalanchePool.claimBonds(_stAmount > stBalance ? stBalance : _stAmount);
        }
    }

    function getEmergencyUnbondings() public override view returns (uint) {
        // avalanchePool automatically transfers the unbonded AVAX to the claimer. This is why there is no _claimUnbonded here
        uint unbondings = avalanchePool.pendingAvaxClaimsOf(address(this));
        return MathUpgradeable.min(unbondings, emergencyUnbondings);
    }

    function _emergencyWithdraw(uint _pendingRedeems) internal override returns (uint _redeemed) {
        uint stBalance = stToken.balanceOf(address(this));
        if (stBalance >= minRedeemAmount) {
            avalanchePool.claimBonds(stBalance);
            emergencyUnbondings = (stBalance > _pendingRedeems) ? stBalance - _pendingRedeems : 0;
            _redeemed = stBalance;
        }
    }

    ///@param _amount Amount of tokens
    function getStTokenByPooledToken(uint _amount) public override view returns(uint) {
        return _amount;
        // return _amount * IAAVAXb(address(stToken)).ratio() / 1e18;
    }

    ///@param _stAmount Amount of stTokens
    function getPooledTokenByStToken(uint _stAmount) public override view returns(uint) {
        return _stAmount;
        // return _stAmount * 1e18 / IAAVAXb(address(stToken)).ratio();
    }
}
