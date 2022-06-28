// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./BNIStrategy.sol";
import "../../../interfaces/IL2Vault.sol";

contract AvaxBNIStrategy is BNIStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant WAVAX = IERC20Upgradeable(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);

    IL2Vault public WAVAXVault;

    event InvestWAVAX(uint USDTAmt, uint WAVAXAmt);

    function setWAVAXVault(IL2Vault _WAVAXVault) external onlyOwner {
        WAVAXVault = _WAVAXVault;
        WAVAX.safeApprove(address(WAVAXVault), type(uint).max);
    }

    function _investWAVAX(uint USDTAmt) private {
        uint WAVAXAmt = WAVAX.balanceOf(address(this));
        if (WAVAXAmt > 0) {
            WAVAXVault.deposit(WAVAXAmt);
            emit InvestWAVAX(USDTAmt, WAVAXAmt);
        }
    }

    function _invest(uint[] memory _USDTAmts) internal virtual override {
        super._invest(_USDTAmts);

        uint poolCnt = _USDTAmts.length;
        for (uint i = 0; i < poolCnt; i ++) {
            address token = tokens[i];
            if (token == address(WAVAX)) {
                _investWAVAX(_USDTAmts[i]);
            }
        }
    }

    function getWAVAXPoolInUSD() private view  returns (uint) {
        uint amt = WAVAXVault.getAllPoolInUSD();
        return amt == 0 ? 0 : amt * WAVAXVault.balanceOf(address(this)) / WAVAXVault.totalSupply(); //to exclude L1 deposits from other addresses
    }

    function _getPoolInUSD(uint _pid) internal view virtual override returns (uint pool) {
        address token = tokens[_pid];
        if (token == address(WAVAX)) {
            pool = getWAVAXPoolInUSD();
        } else {
            pool = super._getPoolInUSD(_pid);
        }
    }
}
