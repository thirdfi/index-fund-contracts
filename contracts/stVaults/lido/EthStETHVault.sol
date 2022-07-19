//SPDX-License-Identifier: MIT
//
///@notice The EthStETHVault contract stakes ETH tokens into stETH on Ethereum.
///@dev https://docs.polkadot.lido.fi/fundamentals/liquid-staking
//
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "../BasicStVault.sol";
import "../../bni/constant/EthConstant.sol";
import "../../../interfaces/ICurvePool.sol";

interface IStETH {
    function getSharesByPooledEth(uint _ethAmount) external view returns (uint);
    function getPooledEthByShares(uint _sharesAmount) external view returns (uint);

    ///@notice Send funds to the pool with optional _referral parameter
    ///@dev This function is alternative way to submit funds. Supports optional referral address.
    ///@return Amount of StETH shares generated
    function submit(address _referral) external payable returns (uint);
}

contract EthStETHVault is BasicStVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    ICurvePool constant curveStEth = ICurvePool(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022); // ETH + stETH

    function initialize(
        address _treasury, address _admin,
        address _priceOracle
    ) public initializer {
        super.initialize(
            "STI L2 stETH", "stiL2StETH",
            _treasury, _admin,
            _priceOracle,
            address(0),
            EthConstant.stETH
        );

        stToken.safeApprove(address(curveStEth), type(uint).max);
    }

    function _invest(uint _amount) internal override returns (uint _invested) {
        IStETH(address(stToken)).submit{value: _amount}(address(0));
        return _amount;
    }

    function withdrawStToken(uint _stAmountToWithdraw) internal override returns (
        uint _withdrawnStAmount,
        uint _withdrawnAmount
    ) {
        _withdrawnAmount = swapStEthForEth(_stAmountToWithdraw);
        _withdrawnStAmount = _stAmountToWithdraw;
    }

    function _emergencyWithdraw(uint _pendingRedeems) internal override returns (uint _redeemed) {
        uint stBalance = stToken.balanceOf(address(this));
        if (stBalance >= minRedeemAmount) {
            swapStEthForEth(stBalance);
            _redeemed = stBalance;
        }
    }

    function swapStEthForEth(uint _stAmount) private returns (uint _ethAmount) {
        uint amountOutMin = getPooledTokenByStToken(_stAmount) * 97 / 100;
        uint balanceBefore = _tokenBalanceOf(address(this));
        curveStEth.exchange(1, 0, _stAmount, amountOutMin);
        _ethAmount = _tokenBalanceOf(address(this)) - balanceBefore;
    }

    ///@param _amount Amount of tokens
    function getStTokenByPooledToken(uint _amount) public override view returns(uint) {
        return IStETH(address(stToken)).getSharesByPooledEth(_amount);
    }

    ///@param _stAmount Amount of stTokens
    function getPooledTokenByStToken(uint _stAmount) public override view returns(uint) {
        return IStETH(address(stToken)).getPooledEthByShares(_stAmount);
    }
}
