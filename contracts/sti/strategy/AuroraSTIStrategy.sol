// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./STIStrategy.sol";
import "../../bni/constant/AuroraConstant.sol";
import "../../../interfaces/IStVault.sol";
import "../../../libs/Const.sol";

contract AuroraSTIStrategy is STIStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IStVault public WNEARVault;

    event InvestWNEAR(uint USDTAmt, uint WNEARAmt);
    event WithdrawWNEAR(uint WNEARAmt, uint USDTAmt, uint reqId);

    function initialize(
        address _treasury, address _admin,
        address _priceOracle,
        IStVault _WNEARVault
    ) public initializer {
        super.initialize(
            _treasury, _admin,
            _priceOracle,
            0x2CB45Edb4517d5947aFdE3BEAbF95A582506858B, // Trisolaris
            AuroraConstant.WNEAR,
            AuroraConstant.USDT,
            AuroraConstant.WNEAR
        );

        WNEARVault = _WNEARVault;

        IERC20Upgradeable(AuroraConstant.WNEAR).safeApprove(address(WNEARVault), type(uint).max);
    }

    function setWNEARVault(IStVault _WNEARVault) external onlyOwner {
        WNEARVault = _WNEARVault;
        if (IERC20Upgradeable(AuroraConstant.WNEAR).allowance(address(this), address(WNEARVault)) == 0) {
            IERC20Upgradeable(AuroraConstant.WNEAR).safeApprove(address(WNEARVault), type(uint).max);
        }
    }

    function _investWNEAR(uint USDTAmt) private {
        uint WNEARAmt = IERC20Upgradeable(AuroraConstant.WNEAR).balanceOf(address(this));
        if (WNEARAmt > 0) {
            WNEARVault.deposit(WNEARAmt);
            emit InvestWNEAR(USDTAmt, WNEARAmt);
        }
    }

    function _invest(uint[] memory _USDTAmts) internal virtual override {
        super._invest(_USDTAmts);

        uint poolCnt = _USDTAmts.length;
        for (uint i = 0; i < poolCnt; i ++) {
            address token = tokens[i];
            if (token == AuroraConstant.WNEAR) {
                _investWNEAR(_USDTAmts[i]);
            }
        }
    }

    function _withdrawWNEAR(uint _sharePerc) private returns (uint USDTAmt, uint reqId) {
        uint amount = WNEARVault.balanceOf(address(this)) * _sharePerc / 1e18;
        if (0 < amount) {
            (uint WNEARAmt, uint _reqId) = WNEARVault.withdraw(amount);
            if (WNEARAmt > 0) {
                USDTAmt = _swapForUSDT(AuroraConstant.WNEAR, WNEARAmt);
            }
            reqId = _reqId;
            emit WithdrawWNEAR(WNEARAmt, USDTAmt, reqId);
        }
    }

    function _withdrawFromPool(address _claimer, uint _pid, uint _sharePerc) internal virtual override returns (uint USDTAmt) {
        address token = tokens[_pid];
        uint reqId;
        if (token == AuroraConstant.WNEAR) {
            (USDTAmt, reqId) = _withdrawWNEAR(_sharePerc);
        } else {
            USDTAmt = super._withdrawFromPool(_claimer, _pid, _sharePerc);
        }

        if (reqId > 0) {
            addReqId(token, _claimer, reqId);
        }
    }

    function getWNEARPoolInUSD() private view  returns (uint) {
        uint amt = WNEARVault.getAllPoolInUSD();
        return amt == 0 ? 0 : amt * WNEARVault.balanceOf(address(this)) / WNEARVault.totalSupply(); //to exclude L1 deposits from other addresses
    }

    function _getPoolInUSD(uint _pid) internal view virtual override returns (uint pool) {
        address token = tokens[_pid];
        if (token == AuroraConstant.WNEAR) {
            pool = getWNEARPoolInUSD();
        } else {
            pool = super._getPoolInUSD(_pid);
        }
    }

    function getAPR() public view override returns (uint) {
        (address[] memory _tokens, uint[] memory perc) = getCurrentTokenCompositionPerc();
        uint allApr;
        uint poolCnt = _tokens.length;
        for (uint i = 0; i < poolCnt; i ++) {
            address token = _tokens[i];
            if (token == AuroraConstant.WNEAR) {
                allApr += WNEARVault.getAPR() * perc[i];
            }
        }
        return (allApr / Const.DENOMINATOR);
    }

}
