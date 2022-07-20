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
import "../BasicStVault.sol";
import "../../bni/constant/AuroraConstant.sol";
import "../../../interfaces/IL2Vault.sol";

interface IMetaPool {
    function swapwNEARForstNEAR(uint _amount) external;
    function swapstNEARForwNEAR(uint _amount) external;
    ///@dev price of stNEAR in wNEAR.
    function stNearPrice() external view returns (uint);
    function wNearSwapFee() external view returns (uint16);
    function stNearSwapFee() external view returns (uint16);
}

contract AuroraStNEARVault is BasicStVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IMetaPool constant metaPool = IMetaPool(0x534BACf1126f60EA513F796a3377ff432BE62cf9);

    IL2Vault public stNEARVault;

    function initialize(
        address _treasury, address _admin,
        address _priceOracle,
        IL2Vault _stNEARVault
    ) public initializer {
        super.initialize(
            "STI L2 stNEAR", "stiL2StNEAR",
            _treasury, _admin,
            _priceOracle,
            AuroraConstant.WNEAR,
            AuroraConstant.stNEAR
        );

        // The backend will call redeem per 1 hour.
        unbondingPeriod = 1 hours;
        minInvestAmount = oneToken;
        // The stNEAR buffer is replenished automatically every 5 minutes.
        investInterval = 5 minutes;
        // The wNEAR buffer is replenished automatically every 5 minutes.
        redeemInterval = 5 minutes;

        stNEARVault = _stNEARVault;

        token.safeApprove(address(metaPool), type(uint).max);
        stToken.safeApprove(address(metaPool), type(uint).max);
        stToken.safeApprove(address(stNEARVault), type(uint).max);
    }

    function _invest(uint _amount) internal override returns (uint _invested) {
        uint stBuffer = stToken.balanceOf(address(metaPool));
        if (stBuffer > 0) {
            uint stNearAmount = getStTokenByPooledToken(_amount);
            if (stBuffer < stNearAmount) {
                _invested = _amount * stBuffer / stNearAmount;
            } else {
                _invested = _amount;
            }
            metaPool.swapwNEARForstNEAR(_invested);
        }
    }

    function _redeem(uint _stAmount) internal override returns (uint _redeemed) {
        uint buffer = token.balanceOf(address(metaPool));
        if (buffer > 0) {
            uint wNearAmount = getPooledTokenByStToken(_stAmount);
            if (buffer < wNearAmount) {
                _redeemed = _stAmount * buffer / wNearAmount;
            } else {
                _redeemed = _stAmount;
            }
            metaPool.swapstNEARForwNEAR(_redeemed);
        }
    }

    function withdrawStToken(uint _stAmountToWithdraw) internal override returns (
        uint _withdrawnStAmount,
        uint _withdrawnAmount
    ) {
        uint balanceBefore = token.balanceOf(address(this));
        _withdrawnStAmount = _redeem(_stAmountToWithdraw);
        _withdrawnAmount = token.balanceOf(address(this)) - balanceBefore;
    }

    function _emergencyWithdraw(uint _pendingRedeems) internal override returns (uint _redeemed) {
        uint stBalance = stToken.balanceOf(address(this));
        if (stBalance >= minRedeemAmount) {
            _redeemed = _redeem(stBalance);
        }
    }

    ///@param _amount Amount of tokens
    function getStTokenByPooledToken(uint _amount) public override view returns(uint) {
        uint stNearAmount = _amount * oneStToken / metaPool.stNearPrice();
        uint feeAmount = (stNearAmount * metaPool.stNearSwapFee()) / DENOMINATOR;
        return stNearAmount - feeAmount;
    }

    ///@param _stAmount Amount of stTokens
    function getPooledTokenByStToken(uint _stAmount) public override view returns(uint) {
        uint wNearAmount = _stAmount * metaPool.stNearPrice() / oneStToken;
        uint feeAmount = wNearAmount * metaPool.wNearSwapFee() / DENOMINATOR;
        return wNearAmount - feeAmount;
    }

    function setL2Vault(IL2Vault _stNEARVault) external onlyOwner {
        stNEARVault = _stNEARVault;
        stToken.safeApprove(address(stNEARVault), type(uint).max);
    }
}
