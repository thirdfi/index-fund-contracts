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
import "../../../libs/Token.sol";

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

    function initialize1(
        address _treasury, address _admin,
        address _priceOracle,
        IL2Vault _stNEARVault
    ) public initializer {
        super.initialize(
            "STI Staking WNEAR", "stiStNEAR",
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
        oneEpoch = 12 hours;

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

            investStNEAR();
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

            uint stBalance = stToken.balanceOf(address(this));
            if (stBalance < _redeemed) {
                withdrawStWNEAR(_redeemed - stBalance);
                stBalance = stToken.balanceOf(address(this));
            }

            if (stBalance > 0) {
                _redeemed = MathUpgradeable.min(_redeemed, stBalance);
                metaPool.swapstNEARForwNEAR(_redeemed);
            } else {
                // Because _stAmount may be a calculation delta in withdraw function,
                // it will reduce the pendingRedeems even though no redeeming on the staking pool.
            }
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
        _pendingRedeems;
        withdrawStWNEAR(type(uint).max);
        uint stBalance = stToken.balanceOf(address(this));
        if (stBalance >= minRedeemAmount) {
            _redeemed = _redeem(stBalance);
        }
    }

    function getInvestedStTokens() public override view returns (uint _stAmount) {
        uint stNEARVaultTotalSupply = stNEARVault.totalSupply();
        if (stNEARVaultTotalSupply > 0) {
            _stAmount = stNEARVault.getAllPool() * stNEARVault.balanceOf(address(this)) / stNEARVaultTotalSupply;
        }
    }

    ///@param _amount Amount of tokens
    function getStTokenByPooledToken(uint _amount) public override view returns(uint) {
        uint stNearAmount = _amount * oneStToken / metaPool.stNearPrice();
        uint feeAmount = (stNearAmount * metaPool.stNearSwapFee()) / Const.DENOMINATOR;
        return stNearAmount - feeAmount;
    }

    ///@param _stAmount Amount of stTokens
    function getPooledTokenByStToken(uint _stAmount) public override view returns(uint) {
        uint wNearAmount = _stAmount * metaPool.stNearPrice() / oneStToken;
        uint feeAmount = wNearAmount * metaPool.wNearSwapFee() / Const.DENOMINATOR;
        return wNearAmount - feeAmount;
    }

    function setL2Vault(IL2Vault _stNEARVault) external onlyOwner {
        stNEARVault = _stNEARVault;
        if (stToken.allowance(address(this), address(stNEARVault)) == 0) {
            stToken.safeApprove(address(stNEARVault), type(uint).max);
        }
    }

    function investStNEAR() private {
        stNEARVault.deposit(stToken.balanceOf(address(this)));
    }

    function withdrawStWNEAR(uint _stAmount) private {
        uint shareBalance = stNEARVault.balanceOf(address(this));
        if (shareBalance > 0) {
            uint shareAmount;
            if (_stAmount != type(uint).max) {
                shareAmount = stNEARVault.totalSupply() * _stAmount / stNEARVault.getAllPool();
                if (shareAmount > shareBalance) shareAmount = shareBalance;
            } else {
                shareAmount = shareBalance;
            }

            stNEARVault.withdraw(shareAmount);
        }
    }

    function getAPR() public virtual override view returns (uint) {
        uint baseApr = super.getAPR();
        uint lendingApr = stNEARVault.getAPR();
        return (1e18 + baseApr) * (1e18 + lendingApr) / 1e18 - 1e18;
    }
}
