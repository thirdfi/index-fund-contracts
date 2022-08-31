//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../../interfaces/IERC20UpgradeableExt.sol";
import "../../../../libs/Const.sol";
import "../../../../libs/Token.sol";
import "../../../bni/IBNIMinter.sol";
import "../../../bni/IBNIVault.sol";
import "../BNIUserAgentBase.sol";

contract UserAgentSubTest is BNIUserAgentBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev It calls depositByAgent of BNIVaults.
    function deposit(
        uint[] memory _toChainIds,
        address[] memory _tokens,
        uint[] memory _USDT6Amts,
        uint _minterNonce
    ) external payable whenNotPaused onlyOwner returns (uint _feeAmt) {
        address account = _msgSender();

        (uint toChainId, address[] memory subTokens, uint[] memory subUSDTAmts, uint newPos)
            = nextDepositData(_toChainIds, _tokens, _USDT6Amts, 0);
        while (toChainId != 0) {
            _feeAmt += _deposit(account, toChainId, subTokens, subUSDTAmts, _minterNonce);
            (toChainId, subTokens, subUSDTAmts, newPos) = nextDepositData(_toChainIds, _tokens, _USDT6Amts, newPos);
        }
    }

    function nextDepositData (
        uint[] memory _toChainIds,
        address[] memory _tokens,
        uint[] memory _USDT6Amts,
        uint pos
    ) private pure returns (
        uint _toChainId,
        address[] memory _subTokens,
        uint[] memory _subUSDTAmts,
        uint _newPos
    ) {
        uint length = _toChainIds.length;
        uint count;
        for (uint i = pos; i < length; i ++) {
            if (_toChainId == 0) {
                _toChainId = _toChainIds[i];
            } else if (_toChainId != _toChainIds[i]) {
                break;
            }
            count ++;
        }

        _newPos = pos + count;
        if (count > 0) {
            _subTokens = new address[](count);
            _subUSDTAmts = new uint[](count);
            count = 0;
            for (uint i = pos; i < _newPos; i ++) {
                _subTokens[count] = _tokens[i];
                _subUSDTAmts[count] = _USDT6Amts[i];
                count ++;
            }
        }
    }

    function _deposit(
        address _account,
        uint _toChainId,
        address[] memory _tokens,
        uint[] memory _USDT6Amts,
        uint _minterNonce
    ) internal virtual returns (uint _feeAmt) {
        if (_toChainId == Token.getChainID()) {
            uint balance = usdtBalances[_account];
            uint amountSum;
            for (uint i = 0; i < _USDT6Amts.length; i ++) {
                amountSum += _USDT6Amts[i];
            }
            amountSum = amountSum * (10 ** (IERC20UpgradeableExt(address(USDT)).decimals() - 6));
            require(balance >= amountSum, "Insufficient balance");
            usdtBalances[_account] = balance - amountSum;

            bniVault.depositByAgent(_account, _tokens, _USDT6Amts, _minterNonce);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                UserAgentSubTest.depositByAgent.selector,
                _account, _tokens, _USDT6Amts, _minterNonce
            );
            _feeAmt = _call(_toChainId, userAgents[_toChainId], 0, _targetCallData, false);
        }
    }

    function depositByAgent(
        address _account,
        address[] memory _tokens,
        uint[] memory _USDT6Amts,
        uint _minterNonce
    ) external onlyRole(ADAPTER_ROLE) {
        bniVault.depositByAgent(_account, _tokens, _USDT6Amts, _minterNonce);
    }

    /// @dev It calls mintByAdmin of BNIMinter.
    function mint(uint _USDT6Amt) external payable virtual whenNotPaused onlyOwner returns (uint _feeAmt) {
        address account = _msgSender();

        if (isLPChain) {
            bniMinter.mintByAdmin(account, _USDT6Amt);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                UserAgentSubTest.mintByAdmin.selector,
                account, _USDT6Amt
            );
            _feeAmt = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData, false);
        }
    }

    function mintByAdmin(address _account, uint _USDT6Amt) external onlyRole(ADAPTER_ROLE) {
        bniMinter.mintByAdmin(_account, _USDT6Amt);
    }

    /// @dev It calls burnByAdmin of BNIMinter.
    /// @param _pool total pool in USD
    /// @param _share amount of shares
    function burn(uint _pool, uint _share) external payable virtual onlyOwner returns (uint _feeAmt) {
        address account = _msgSender();

        if (isLPChain) {
            bniMinter.burnByAdmin(account, _pool, _share);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                UserAgentSubTest.burnByAdmin.selector,
                account, _pool, _share
            );
            _feeAmt = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData, false);
        }
    }

    function burnByAdmin(address _account, uint _pool, uint _share) external onlyRole(ADAPTER_ROLE) {
        bniMinter.burnByAdmin(_account, _pool, _share);
    }

    /// @dev It calls withdrawPercByAgent of BNIVaults.
    function withdraw(
        uint[] memory _chainIds, uint _sharePerc, uint _minterNonce
    ) external payable onlyOwner returns (uint _feeAmt) {
        address account = _msgSender();

        for (uint i = 0; i < _chainIds.length; i ++) {
            _feeAmt += _withdraw(account, _chainIds[i], _sharePerc, _minterNonce);
        }
    }

    function _withdraw(
        address _account, uint _chainId, uint _sharePerc, uint _minterNonce
    ) internal virtual returns (uint _feeAmt) {
        if (_chainId == Token.getChainID()) {
            _withdrawFromVault(bniVault, _account, _sharePerc, _minterNonce);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                UserAgentSubTest.withdrawPercByAgent.selector,
                _account, _sharePerc, _minterNonce
            );
            _feeAmt = _call(_chainId, userAgents[_chainId], 0, _targetCallData, false);
        }
    }

    function withdrawPercByAgent(
        address _account, uint _sharePerc, uint _minterNonce
    ) external onlyRole(ADAPTER_ROLE) {
        _withdrawFromVault(bniVault, _account, _sharePerc, _minterNonce);
    }

    function _withdrawFromVault(
        IBNIVault _bniVault, address _account, uint _sharePerc, uint _minterNonce
    ) internal {
        uint balanceBefore = USDT.balanceOf(address(this));
        _bniVault.withdrawPercByAgent(_account, _sharePerc, _minterNonce);
        usdtBalances[_account] += (USDT.balanceOf(address(this)) - balanceBefore);
    }

    /// @dev It gathers withdrawn tokens of the user from user agents.
    function gather(
        uint[] memory _fromChainIds,
        AdapterType[] memory _adapterTypes
    ) external payable virtual onlyOwner returns (uint _feeAmt) {
        address account = _msgSender();

        for (uint i = 0; i < _fromChainIds.length; i ++) {
            _feeAmt += _gather(account, _fromChainIds[i], _adapterTypes[i]);
        }
    }

    function _gather(
        address _account, uint _fromChainId, AdapterType _adapterType
    ) private returns (uint _feeAmt) {
        uint chainId = Token.getChainID();
        if (_fromChainId != chainId) {
            bytes memory _targetCallData = abi.encodeWithSelector(
                UserAgentSubTest.gatherByAdmin.selector,
                _account, chainId, _adapterType
            );
            _feeAmt = _call(_fromChainId, userAgents[_fromChainId], 0, _targetCallData, false);
        }
    }

    function gatherByAdmin(
        address _account, uint _toChainId, AdapterType _adapterType
    ) external onlyRole(ADAPTER_ROLE) {
        uint balance = usdtBalances[_account];
        if (balance > 0) {
            address toUserAgent = userAgents[_toChainId];
            require(toUserAgent != address(0), "Invalid user agent");

            uint[] memory amounts = new uint[](1);
            amounts[0] = balance;
            uint[] memory toChainIds = new uint[](1);
            toChainIds[0] = _toChainId;
            address[] memory toAddresses = new address[](1);
            toAddresses[0] = toUserAgent;
            AdapterType[] memory adapterTypes = new AdapterType[](1);
            adapterTypes[0] = _adapterType;

            uint feeAmt = _transfer(_account, address(USDT), amounts, toChainIds, toAddresses, adapterTypes, 1, true);
            uint tokensForFee = swap.getAmountsInForETH(address(USDT), feeAmt);
            if (balance > tokensForFee) {
                uint spentTokenAmount = swap.swapTokensForExactETH(address(USDT), tokensForFee, feeAmt);
                amounts[0] = balance - spentTokenAmount;
                usdtBalances[_account] = 0;

                _transfer(_account, address(USDT), amounts, toChainIds, toAddresses, adapterTypes, 1, false);
            }
        }
    }

    /// @dev It calls exitWithdrawalByAdmin of BNIMinter.
    /// @param _gatheredAmount is the amount of token that is gathered.
    /// @notice _gatheredAmount doesn't include the balance which is withdrawan in this agent.
    function exitWithdrawal(uint _gatheredAmount) external payable virtual onlyOwner returns (uint _feeAmt) {
        address account = _msgSender();

        if (isLPChain) {
            bniMinter.exitWithdrawalByAdmin(account);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                UserAgentSubTest.exitWithdrawalByAdmin.selector,
                account
            );
            _feeAmt = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData, false);
        }

        uint amount = _gatheredAmount + usdtBalances[account];
        usdtBalances[account] = 0;
        USDT.safeTransfer(account, amount);
    }

    function exitWithdrawalByAdmin(address _account) external onlyRole(ADAPTER_ROLE) {
        bniMinter.exitWithdrawalByAdmin(_account);
    }

    /// @dev It takes out tokens from this agent.
    /// @param _gatheredAmount is the amount of token that is gathered.
    /// @notice _gatheredAmount doesn't include the balance which is withdrawan in this agent.
    function takeOut(uint _gatheredAmount) external onlyOwner {
        address account = _msgSender();

        uint amount = _gatheredAmount + usdtBalances[account];
        usdtBalances[account] = 0;
        USDT.safeTransfer(account, amount);
    }
}
