//SPDX-License-Identifier: MIT
//
///@notice The MoonbeamStDOTVault contract stakes xcDOT tokens into stDOT on Moonbeam.
///@dev https://docs.polkadot.lido.fi/fundamentals/liquid-staking
//
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "../BasicStVault.sol";
import "../../bni/constant/MoonbeamConstant.sol";

interface IStDOT {
    function getUnbonded(address _holder) external view returns (uint waiting, uint unbonded);
    function deposit(uint _amount) external returns (uint);
    function redeem(uint _amount) external;
    function claimUnbonded() external;
    function getSharesByPooledKSM(uint _amount) external view returns (uint);
    function getPooledKSMByShares(uint _sharesAmount) external view returns (uint);
}

contract MoonbeamStDOTVault is BasicStVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize(
        address _treasury, address _admin,
        address _priceOracle
    ) public initializer {
        super.initialize(
            "STI L2 stDOT", "stiL2StDOT",
            _treasury, _admin,
            _priceOracle,
            MoonbeamConstant.xcDOT,
            MoonbeamConstant.stDOT
        );

        unbondingPeriod = 30 days;

        token.safeApprove(address(stToken), type(uint).max);
    }

    function _invest(uint _amount) internal override {
        IStDOT(address(stToken)).deposit(_amount);
    }

    function _redeem(uint _pendingRedeems) internal override {
        IStDOT(address(stToken)).redeem(_pendingRedeems);
    }

    function _claimUnbonded() internal override {
        uint balanceBefore = token.balanceOf(address(this));
        IStDOT(address(stToken)).claimUnbonded();

        uint _bufferedWithdrawals = bufferedWithdrawals + (token.balanceOf(address(this)) - balanceBefore);
        uint _pendingWithdrawals = pendingWithdrawals;
        bufferedWithdrawals = MathUpgradeable.min(_bufferedWithdrawals, _pendingWithdrawals);

        if (emergencyRedeems != 0 && paused() && getUnbondedToken() == 0) {
            // The tokens according to the emergency redeem has been claimed
            emergencyRedeems = 0;
        }
    }

    function _emergencyWithdraw(uint _pendingRedeems) internal override {
        uint stBalance = stToken.balanceOf(address(this));
        if (stBalance >= minRedeemAmount) {
            IStDOT(address(stToken)).redeem(stBalance);
            emergencyRedeems = (stBalance - _pendingRedeems);
        }
    }

    ///@param _amount Amount of tokens
    function getStTokenByPooledToken(uint _amount) public override view returns(uint) {
        return IStDOT(address(stToken)).getSharesByPooledKSM(_amount);
    }

    ///@param _stAmount Amount of stTokens
    function getPooledTokenByStToken(uint _stAmount) public override view returns(uint) {
        return IStDOT(address(stToken)).getPooledKSMByShares(_stAmount);
    }

    function getUnbondedToken() public override view returns (uint _amount) {
        (, _amount) = IStDOT(address(stToken)).getUnbonded(address(this));
    }
}
