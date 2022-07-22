//SPDX-License-Identifier: MIT
//
///@notice The MoonbeamStDOTVault contract stakes xcDOT tokens into stDOT on Moonbeam.
///@dev https://docs.polkadot.lido.fi/fundamentals/liquid-staking
//
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
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
        oneEpoch = 24 hours;

        token.safeApprove(address(stToken), type(uint).max);
    }

    function _invest(uint _amount) internal override returns (uint _invested) {
        IStDOT(address(stToken)).deposit(_amount);
        return _amount;
    }

    function _redeem(uint _stAmount) internal override returns (uint _redeemed) {
        IStDOT(address(stToken)).redeem(_stAmount);
        return _stAmount;
    }

    function _claimUnbonded() internal override {
        IStDOT(address(stToken)).claimUnbonded();

        uint _emergencyUnbondings = emergencyUnbondings;
        if (_emergencyUnbondings > 0 && paused()) {
            (uint unbondings,) = IStDOT(address(stToken)).getUnbonded(address(this));
            if (_emergencyUnbondings > unbondings) {
                emergencyUnbondings = unbondings;
            }
        }
    }

    function _emergencyWithdraw(uint _pendingRedeems) internal override returns (uint _redeemed) {
        uint stBalance = stToken.balanceOf(address(this));
        if (stBalance >= minRedeemAmount) {
            IStDOT(address(stToken)).redeem(stBalance);
            emergencyUnbondings = (stBalance - _pendingRedeems);
            _redeemed = stBalance;
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
