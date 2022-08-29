//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../interfaces/IERC20UpgradeableExt.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../../sti/ISTIMinter.sol";
import "../../sti/ISTIVault.sol";
import "./STIUserAgentSub.sol";

contract STIUserAgentSubTest is STIUserAgentSub {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function _deposit(
        address _account,
        uint _toChainId,
        address[] memory _tokens,
        uint[] memory _USDT6Amts,
        uint _minterNonce
    ) internal override returns (uint _feeAmt) {
        ISTIVault stiVault = stiVaults[_toChainId];
        require(address(stiVault) != address(0), "Invalid stiVault");

        if (_toChainId == Token.getChainID()) {
            uint balance = usdtBalances[_account];
            uint amountSum;
            for (uint i = 0; i < _USDT6Amts.length; i ++) {
                amountSum += _USDT6Amts[i];
            }
            amountSum = amountSum * (10 ** (IERC20UpgradeableExt(address(USDT)).decimals() - 6));
            require(balance >= amountSum, "Insufficient balance");
            usdtBalances[_account] = balance - amountSum;

            stiVault.depositByAgent(_account, _tokens, _USDT6Amts, _minterNonce);
        } else {
            // NOTE: cBridge doesn't support liquidity on testnets
            _feeAmt = 0;
        }
    }

    function mint(uint _USDT6Amt, bytes calldata _signature) external payable override whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _USDT6Amt)), _signature);

        if (isLPChain) {
            stiMinter.mintByAdmin(account, _USDT6Amt);
        } else {
            // NOTE: cBridge is not supported on Rinkeby
            _feeAmt = 0;
        }
        nonces[account] = _nonce + 1;
    }

    function burn(uint _pool, uint _share, bytes calldata _signature) external payable override returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _pool, _share)), _signature);

        if (isLPChain) {
            stiMinter.burnByAdmin(account, _pool, _share);
        } else {
            // NOTE: cBridge is not supported on Rinkeby
            _feeAmt = 0;
        }
        nonces[account] = _nonce + 1;
    }

    function _withdraw(
        address _account, uint _chainId, uint _sharePerc, uint _minterNonce
    ) internal override returns (uint _feeAmt) {
        ISTIVault stiVault = stiVaults[_chainId];
        require(address(stiVault) != address(0), "Invalid stiVault");

        if (_chainId == Token.getChainID()) {
            _withdrawFromVault(stiVault, _account, _sharePerc, _minterNonce);
        } else {
            // NOTE: cBridge doesn't support liquidity on testnets
            _feeAmt = 0;
        }
    }

    function gather(
        uint[] memory _fromChainIds,
        AdapterType[] memory _adapterTypes,
        bytes calldata _signature
    ) external payable override returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _fromChainIds, _adapterTypes)), _signature);

        // NOTE: cBridge doesn't support liquidity on testnets
        _feeAmt = 0;
        nonces[account] = _nonce + 1;
    }

    function exitWithdrawal(uint _gatheredAmount, bytes calldata _signature) external payable override returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _gatheredAmount)), _signature);

        if (isLPChain) {
            stiMinter.exitWithdrawalByAdmin(account);
        } else {
            // NOTE: cBridge is not supported on Rinkeby
            _feeAmt = 0;
        }

        uint amount = _gatheredAmount + usdtBalances[account];
        usdtBalances[account] = 0;
        USDT.safeTransfer(account, amount);

        nonces[account] = _nonce + 1;
    }

    function claim(
        uint[] memory _chainIds, bytes calldata _signature
    ) external payable override returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _chainIds)), _signature);

        // NOTE: cBridge doesn't support liquidity on testnets
        _feeAmt = 0;
        nonces[account] = _nonce + 1;
    }

}
