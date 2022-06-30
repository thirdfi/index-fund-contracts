// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./BNIStrategy.sol";
import "../../../interfaces/IL2Vault.sol";

contract MaticBNIStrategy is BNIStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant WMATIC = IERC20Upgradeable(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

    IL2Vault public WMATICVault;

    event InvestWMATIC(uint USDTAmt, uint WMATICAmt);
    event WithdrawWMATIC(uint WMATICAmt, uint USDTAmt);

    function setWMATICVault(IL2Vault _WMATICVault) external onlyOwner {
        WMATICVault = _WMATICVault;
        WMATIC.safeApprove(address(WMATICVault), type(uint).max);
    }

    function _investWMATIC(uint USDTAmt) private {
        uint WMATICAmt = WMATIC.balanceOf(address(this));
        if (WMATICAmt > 0) {
            WMATICVault.deposit(WMATICAmt);
            emit InvestWMATIC(USDTAmt, WMATICAmt);
        }
    }

    function _invest(uint[] memory _USDTAmts) internal virtual override {
        super._invest(_USDTAmts);

        uint poolCnt = _USDTAmts.length;
        for (uint i = 0; i < poolCnt; i ++) {
            address token = tokens[i];
            if (token == address(WMATIC)) {
                _investWMATIC(_USDTAmts[i]);
            }
        }
    }

    function _withdrawWMATIC(uint _sharePerc) private returns (uint USDTAmt) {
        uint amount = WMATICVault.balanceOf(address(this)) * _sharePerc / 1e18;
        if (0 < amount) {
            WMATICVault.withdraw(amount);
            uint WMATICAmt = WMATIC.balanceOf(address(this));
            USDTAmt = _swapForUSDT(address(WMATIC), WMATICAmt);
            emit WithdrawWMATIC(WMATICAmt, USDTAmt);
        }
    }

    function _withdrawFromPool(uint _pid, uint _sharePerc) internal virtual override returns (uint USDTAmt) {
        address token = tokens[_pid];
        if (token == address(WMATIC)) {
            USDTAmt = _withdrawWMATIC(_sharePerc);
        } else {
            USDTAmt = super._withdrawFromPool(_pid, _sharePerc);
        }
    }

    function getWMATICPoolInUSD() private view  returns (uint) {
        uint amt = WMATICVault.getAllPoolInUSD();
        return amt == 0 ? 0 : amt * WMATICVault.balanceOf(address(this)) / WMATICVault.totalSupply(); //to exclude L1 deposits from other addresses
    }

    function _getPoolInUSD(uint _pid) internal view virtual override returns (uint pool) {
        address token = tokens[_pid];
        if (token == address(WMATIC)) {
            pool = getWMATICPoolInUSD();
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
            if (token == address(WMATIC)) {
                allApr += WMATICVault.getAPR() * perc[i];
            }
        }
        return (allApr / DENOMINATOR);
    }
}
