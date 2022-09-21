//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../interfaces/IERC20UpgradeableExt.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../../bni/IBNIMinter.sol";
import "../../bni/IBNIVault.sol";
import "./BNIUserAgentBase.sol";

contract BNIUserAgentSub is BNIUserAgentBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct DepositPerChain {
        uint toChainId;
        address[] tokens;
        uint[] USDT6Amts;
    }

    event SkipGathering(address account, uint balance, uint tokensForFee);

    /// @dev It transfers tokens to user agents
    function transfer(
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        AdapterType[] memory _adapterTypes,
        bytes calldata _signature
    ) external payable virtual whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint leftFee = msg.value;
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _amounts, _toChainIds, _adapterTypes)), _signature);

        (address[] memory toAddresses, uint lengthOut) = transferIn(account, _amounts, _toChainIds, _adapterTypes);
        if (lengthOut > 0) {
            (_feeAmt, leftFee) = _transfer(account, address(USDT), _amounts, _toChainIds, toAddresses, _adapterTypes, lengthOut, leftFee, false);
        }
        nonces[account] = _nonce + 1;
        if (leftFee > 0) Token.safeTransferETH(account, leftFee);
    }

    function transferIn(
        address account,
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        AdapterType[] memory _adapterTypes
    ) internal returns (address[] memory _toAddresses, uint _lengthOut) {
        uint length = _amounts.length;
        _toAddresses = new address[](length);
        uint chainId = Token.getChainID();
        uint amountOn;
        uint amountOut;
        for (uint i = 0; i < length; i ++) {
            uint amount = _amounts[i];
            uint toChainId = _toChainIds[i];
            if (toChainId == chainId) {
                amountOn += amount;
            } else {
                if (_lengthOut != i) {
                    _amounts[_lengthOut] = amount;
                    _toChainIds[_lengthOut] = toChainId;
                    _adapterTypes[_lengthOut] = _adapterTypes[i];
                }
                address toUserAgent = userAgents[toChainId];
                require(toUserAgent != address(0), "Invalid user agent");
                _toAddresses[_lengthOut] = toUserAgent;

                _lengthOut ++;
                amountOut += amount;
            }
        }

        USDT.safeTransferFrom(account, address(this), amountOn + amountOut);
        usdtBalances[account] += amountOn;
    }

    /// @dev It calls depositByAgent of BNIVaults.
    function deposit(
        uint[] memory _toChainIds,
        address[] memory _tokens,
        uint[] memory _USDT6Amts,
        uint _minterNonce,
        bytes calldata _signature
    ) external payable whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint leftFee = msg.value;
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _toChainIds, _tokens, _USDT6Amts, _minterNonce)), _signature);

        uint feeAmt;
        (DepositPerChain memory depositPerChain, uint newPos) = nextDepositData(_toChainIds, _tokens, _USDT6Amts, 0);
        while (depositPerChain.toChainId != 0) {
            (feeAmt, leftFee) = _deposit(account, depositPerChain, _minterNonce, leftFee);
            _feeAmt += feeAmt;
            (depositPerChain, newPos) = nextDepositData(_toChainIds, _tokens, _USDT6Amts, newPos);
        }

        nonces[account] = _nonce + 1;
        if (leftFee > 0) Token.safeTransferETH(account, leftFee);
    }

    function nextDepositData (
        uint[] memory _toChainIds,
        address[] memory _tokens,
        uint[] memory _USDT6Amts,
        uint pos
    ) private pure returns (
        DepositPerChain memory _depositPerChain,
        uint _newPos
    ) {
        uint toChainId;
        address[] memory subTokens;
        uint[] memory subUSDTAmts;
        uint count;
        for (uint i = pos; i < _toChainIds.length; i ++) {
            if (toChainId == 0) {
                toChainId = _toChainIds[i];
            } else if (toChainId != _toChainIds[i]) {
                break;
            }
            count ++;
        }

        _newPos = pos + count;
        if (count > 0) {
            subTokens = new address[](count);
            subUSDTAmts = new uint[](count);
            count = 0;
            for (uint i = pos; i < _newPos; i ++) {
                subTokens[count] = _tokens[i];
                subUSDTAmts[count] = _USDT6Amts[i];
                count ++;
            }
        }

        _depositPerChain = DepositPerChain({
            toChainId: toChainId,
            tokens: subTokens,
            USDT6Amts: subUSDTAmts
        });
    }

    function _deposit(
        address _account,
        DepositPerChain memory _depositPerChain,
        uint _minterNonce,
        uint _suppliedFee
    ) internal virtual returns (uint _feeAmt, uint _leftFee) {
        _leftFee = _suppliedFee;
        if (_depositPerChain.toChainId == Token.getChainID()) {
            uint balance = usdtBalances[_account];
            uint amountSum;
            for (uint i = 0; i < _depositPerChain.USDT6Amts.length; i ++) {
                amountSum += _depositPerChain.USDT6Amts[i];
            }
            amountSum = amountSum * (10 ** (IERC20UpgradeableExt(address(USDT)).decimals() - 6));
            require(balance >= amountSum, "Insufficient balance");
            usdtBalances[_account] = balance - amountSum;

            bniVault.depositByAgent(_account, _depositPerChain.tokens, _depositPerChain.USDT6Amts, _minterNonce);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                BNIUserAgentSub.depositByAgent.selector,
                _account, _depositPerChain.tokens, _depositPerChain.USDT6Amts, _minterNonce
            );
            (_feeAmt, _leftFee) = _call(_depositPerChain.toChainId, userAgents[_depositPerChain.toChainId], 0, _targetCallData,
                                        IBNIVault.depositByAdmin.selector, _leftFee, false);
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
    function mint(uint _USDT6Amt, bytes calldata _signature) external payable virtual whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint leftFee = msg.value;
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _USDT6Amt)), _signature);

        if (isLPChain) {
            bniMinter.mintByAdmin(account, _USDT6Amt);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                BNIUserAgentSub.mintByAdmin.selector,
                account, _USDT6Amt
            );
            (_feeAmt, leftFee) = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData,
                                        IBNIMinter.mintByAdmin.selector, leftFee, false);
        }
        nonces[account] = _nonce + 1;
        if (leftFee > 0) Token.safeTransferETH(account, leftFee);
    }

    function mintByAdmin(address _account, uint _USDT6Amt) external onlyRole(ADAPTER_ROLE) {
        bniMinter.mintByAdmin(_account, _USDT6Amt);
    }

    /// @dev It calls burnByAdmin of BNIMinter.
    /// @param _pool total pool in USD
    /// @param _share amount of shares
    function burn(uint _pool, uint _share, bytes calldata _signature) external payable virtual returns (uint _feeAmt) {
        address account = _msgSender();
        uint leftFee = msg.value;
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _pool, _share)), _signature);

        if (isLPChain) {
            bniMinter.burnByAdmin(account, _pool, _share);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                BNIUserAgentSub.burnByAdmin.selector,
                account, _pool, _share
            );
            (_feeAmt, leftFee) = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData,
                                        IBNIMinter.burnByAdmin.selector, leftFee, false);
        }
        nonces[account] = _nonce + 1;
        if (leftFee > 0) Token.safeTransferETH(account, leftFee);
    }

    function burnByAdmin(address _account, uint _pool, uint _share) external onlyRole(ADAPTER_ROLE) {
        bniMinter.burnByAdmin(_account, _pool, _share);
    }

    /// @dev It calls withdrawPercByAgent of BNIVaults.
    function withdraw(
        uint[] memory _chainIds, uint _sharePerc, uint _minterNonce, bytes calldata _signature
    ) external payable returns (uint _feeAmt) {
        address account = _msgSender();
        uint leftFee = msg.value;
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _chainIds, _sharePerc, _minterNonce)), _signature);

        uint feeAmt;
        for (uint i = 0; i < _chainIds.length; i ++) {
            (feeAmt, leftFee) = _withdraw(account, _chainIds[i], _sharePerc, _minterNonce, leftFee);
            _feeAmt += feeAmt;
        }
        nonces[account] = _nonce + 1;
        if (leftFee > 0) Token.safeTransferETH(account, leftFee);
    }

    function _withdraw(
        address _account,
        uint _chainId,
        uint _sharePerc,
        uint _minterNonce,
        uint _suppliedFee
    ) internal virtual returns (uint _feeAmt, uint _leftFee) {
        _leftFee = _suppliedFee;
        if (_chainId == Token.getChainID()) {
            _withdrawFromVault(bniVault, _account, _sharePerc, _minterNonce);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                BNIUserAgentSub.withdrawPercByAgent.selector,
                _account, _sharePerc, _minterNonce
            );
            (_feeAmt, _leftFee) = _call(_chainId, userAgents[_chainId], 0, _targetCallData,
                                        IBNIVault.withdrawPercByAdmin.selector, _leftFee, false);
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
        AdapterType[] memory _adapterTypes,
        bytes calldata _signature
    ) external payable virtual returns (uint _feeAmt) {
        address account = _msgSender();
        uint leftFee = msg.value;
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _fromChainIds, _adapterTypes)), _signature);

        uint feeAmt;
        for (uint i = 0; i < _fromChainIds.length; i ++) {
            (feeAmt, leftFee) = _gather(account, _fromChainIds[i], _adapterTypes[i], leftFee);
            _feeAmt += feeAmt;
        }
        nonces[account] = _nonce + 1;
        if (leftFee > 0) Token.safeTransferETH(account, leftFee);
    }

    function _gather(
        address _account,
        uint _fromChainId,
        AdapterType _adapterType,
        uint _suppliedFee
    ) private returns (uint _feeAmt, uint _leftFee) {
        _leftFee = _suppliedFee;
        uint chainId = Token.getChainID();
        if (_fromChainId != chainId) {
            bytes memory _targetCallData = abi.encodeWithSelector(
                BNIUserAgentSub.gatherByAdmin.selector,
                _account, chainId, _adapterType
            );
            (_feeAmt, _leftFee) = _call(_fromChainId, userAgents[_fromChainId], 0, _targetCallData,
                                        BNIUserAgentSub.gatherByAdmin.selector, _leftFee, false);
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

            (uint feeAmt,) = _transfer(_account, address(USDT), amounts, toChainIds, toAddresses, adapterTypes, 1, 0, true);
            uint tokensForFee = swap.getAmountsInForETH(address(USDT), feeAmt);
            if (balance > (tokensForFee + minTransfer(address(USDT), _toChainId, _adapterType))) {
                uint spentTokenAmount = swap.swapTokensForExactETH(address(USDT), tokensForFee, feeAmt);
                amounts[0] = balance - spentTokenAmount;
                usdtBalances[_account] = 0;

                _transfer(_account, address(USDT), amounts, toChainIds, toAddresses, adapterTypes, 1, feeAmt, false);
            } else {
                emit SkipGathering(_account, balance, tokensForFee);
            }
        }
    }

    /// @dev It calls exitWithdrawalByAdmin of BNIMinter.
    /// @param _gatheredAmount is the amount of token that is gathered.
    /// @notice _gatheredAmount doesn't include the balance which is withdrawan in this agent.
    function exitWithdrawal(uint _gatheredAmount, bytes calldata _signature) external payable virtual returns (uint _feeAmt) {
        address account = _msgSender();
        uint leftFee = msg.value;
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _gatheredAmount)), _signature);

        if (isLPChain) {
            bniMinter.exitWithdrawalByAdmin(account);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                BNIUserAgentSub.exitWithdrawalByAdmin.selector,
                account
            );
            (_feeAmt, leftFee) = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData,
                                        IBNIVault.withdrawPercByAdmin.selector, leftFee, false);
        }

        uint amount = _gatheredAmount + usdtBalances[account];
        usdtBalances[account] = 0;
        USDT.safeTransfer(account, amount);

        nonces[account] = _nonce + 1;
        if (leftFee > 0) Token.safeTransferETH(account, leftFee);
    }

    function exitWithdrawalByAdmin(address _account) external onlyRole(ADAPTER_ROLE) {
        bniMinter.exitWithdrawalByAdmin(_account);
    }

    /// @dev It takes out tokens from this agent.
    /// @param _gatheredAmount is the amount of token that is gathered.
    /// @notice _gatheredAmount doesn't include the balance which is withdrawan in this agent.
    function takeOut(uint _gatheredAmount, bytes calldata _signature) external {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _gatheredAmount)), _signature);

        uint amount = _gatheredAmount + usdtBalances[account];
        usdtBalances[account] = 0;
        USDT.safeTransfer(account, amount);

        nonces[account] = _nonce + 1;
    }
}
