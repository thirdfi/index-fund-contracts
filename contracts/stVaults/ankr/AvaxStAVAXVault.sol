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

interface IAvalanchePool {
    function stakeAndClaimBonds() external payable;
    function stakeAndClaimCerts() external payable;
    function pendingAvaxClaimsOf(address claimer) external view returns (uint);
    function claimBonds(uint amount) external;
    function claimCerts(uint amount) external;
}

interface IAAVAXb {
    function ratio() external view returns (uint);
    function sharesToBalance(uint amount) external view returns (uint);
}

contract AvaxStAVAXVault is BasicStVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IAvalanchePool public avalanchePool;

    function initialize(
        address _treasury, address _admin,
        address _priceOracle,
        address _avalanchePool
    ) public initializer {
        super.initialize(
            "STI L2 stAVAX", "stiL2StAVAX",
            _treasury, _admin,
            _priceOracle,
            address(0), // AVAX
            AvaxConstant.aAVAXb
        );

        unbondingPeriod = 28 days;
        minInvestAmount = oneToken;

        avalanchePool = IAvalanchePool(_avalanchePool);
    }

    function _invest(uint _amount) internal override {
        avalanchePool.stakeAndClaimBonds{value: _amount}();
    }

    function _redeem(uint _pendingRedeems) internal override {
        avalanchePool.claimBonds(_pendingRedeems);
    }

    function _emergencyWithdraw(uint _pendingRedeems) internal override {
        uint stBalance = stToken.balanceOf(address(this));
        if (stBalance >= minRedeemAmount) {
            avalanchePool.claimBonds(stBalance);
            emergencyRedeems = (stBalance - _pendingRedeems);
        }
    }

    ///@param _amount Amount of tokens
    function getStTokenByPooledToken(uint _amount) public override view returns(uint) {
        return _amount * IAAVAXb(address(stToken)).ratio() / 1e18;
    }

    ///@param _stAmount Amount of stTokens
    function getPooledTokenByStToken(uint _stAmount) public override view returns(uint) {
        return _stAmount * 1e18 / IAAVAXb(address(stToken)).ratio();
    }
}
