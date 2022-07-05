// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./BNIStrategy.sol";
import "../../../interfaces/IL2Vault.sol";

contract AuroraBNIStrategy is BNIStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant WNEAR = IERC20Upgradeable(0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d);

    IL2Vault public WNEARVault;

    event InvestWNEAR(uint USDTAmt, uint WNEARAmt);
    event WithdrawWNEAR(uint WNEARAmt, uint USDTAmt);

    function setWNEARVault(IL2Vault _WNEARVault) external onlyOwner {
        WNEARVault = _WNEARVault;
        WNEAR.safeApprove(address(WNEARVault), type(uint).max);
    }

    function _investWNEAR(uint USDTAmt) private {
        uint WNEARAmt = WNEAR.balanceOf(address(this));
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
            if (token == address(WNEAR)) {
                _investWNEAR(_USDTAmts[i]);
            }
        }
    }

    function _withdrawWNEAR(uint _sharePerc) private returns (uint USDTAmt) {
        uint amount = WNEARVault.balanceOf(address(this)) * _sharePerc / 1e18;
        if (0 < amount) {
            WNEARVault.withdraw(amount);
            uint WNEARAmt = WNEAR.balanceOf(address(this));
            USDTAmt = _swapForUSDT(address(WNEAR), WNEARAmt);
            emit WithdrawWNEAR(WNEARAmt, USDTAmt);
        }
    }

    function _withdrawFromPool(uint _pid, uint _sharePerc) internal virtual override returns (uint USDTAmt) {
        address token = tokens[_pid];
        if (token == address(WNEAR)) {
            USDTAmt = _withdrawWNEAR(_sharePerc);
        } else {
            USDTAmt = super._withdrawFromPool(_pid, _sharePerc);
        }
    }

    function getWNEARPoolInUSD() private view  returns (uint) {
        uint amt = WNEARVault.getAllPoolInUSD();
        return amt == 0 ? 0 : amt * WNEARVault.balanceOf(address(this)) / WNEARVault.totalSupply(); //to exclude L1 deposits from other addresses
    }

    function _getPoolInUSD(uint _pid) internal view virtual override returns (uint pool) {
        address token = tokens[_pid];
        if (token == address(WNEAR)) {
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
            if (token == address(WNEAR)) {
                allApr += WNEARVault.getAPR() * perc[i];
            }
        }
        return (allApr / DENOMINATOR);
    }

}
