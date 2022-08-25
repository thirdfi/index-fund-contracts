//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../../bni/IBNIMinter.sol";
import "../../bni/IBNIVault.sol";
import "./BNIUserAgentBase.sol";

contract BNIUserAgentSub is BNIUserAgentBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev It calls depositByAdmin of BNIVaults.
    function deposit(
        uint[] memory _toChainIds,
        address[] memory _tokens,
        uint[] memory _USDTAmts,
        uint _minterNonce,
        bytes calldata _signature
    ) external payable whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _toChainIds, _tokens, _USDTAmts, _minterNonce)), _signature);

        (uint toChainId, address[] memory subTokens, uint[] memory subUSDTAmts, uint newPos)
            = nextDepositData(_toChainIds, _tokens, _USDTAmts, 0);
        while (toChainId != 0) {
            _feeAmt += _deposit(account, toChainId, subTokens, subUSDTAmts, _minterNonce);
            (toChainId, subTokens, subUSDTAmts, newPos) = nextDepositData(_toChainIds, _tokens, _USDTAmts, newPos);
        }

        nonces[account] = _nonce + 1;
    }

    function nextDepositData (
        uint[] memory _toChainIds,
        address[] memory _tokens,
        uint[] memory _USDTAmts,
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
                _subUSDTAmts[count] = _USDTAmts[i];
                count ++;
            }
        }
    }

    function _deposit(
        address _account,
        uint _toChainId,
        address[] memory _tokens,
        uint[] memory _USDTAmts,
        uint _minterNonce
    ) private returns (uint _feeAmt) {
        IBNIVault bniVault = bniVaults[_toChainId];
        require(address(bniVault) != address(0), "Invalid bniVault");

        if (_toChainId == Token.getChainID()) {
            uint balance = usdtBalances[_account];
            uint amountSum;
            for (uint i = 0; i < _USDTAmts.length; i ++) {
                amountSum += _USDTAmts[i];
            }
            require(balance >= amountSum, "Insufficient balance");
            usdtBalances[_account] = balance - amountSum;

            bniVault.depositByAdmin(_account, _tokens, _USDTAmts, _minterNonce);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                BNIUserAgentSub.depositByAdmin.selector,
                _account, _tokens, _USDTAmts, _minterNonce
            );
            _feeAmt = _call(_toChainId, userAgents[_toChainId], 0, _targetCallData, false);
        }
    }

    function depositByAdmin(
        address _account,
        address[] memory _tokens,
        uint[] memory _USDTAmts,
        uint _minterNonce
    ) external onlyRole(ADAPTER_ROLE) {
        IBNIVault bniVault = bniVaults[Token.getChainID()];
        bniVault.depositByAdmin(_account, _tokens, _USDTAmts, _minterNonce);
    }

    /// @dev It calls mintByAdmin of BNIMinter.
    function mint(uint _USDTAmt, bytes calldata _signature) external payable whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _USDTAmt)), _signature);

        if (isLPChain) {
            bniMinter.mintByAdmin(account, _USDTAmt);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                BNIUserAgentSub.mintByAdmin.selector,
                account, _USDTAmt
            );
            _feeAmt = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData, false);
        }
        nonces[account] = _nonce + 1;
    }

    function mintByAdmin(address _account, uint _USDTAmt) external onlyRole(ADAPTER_ROLE) {
        bniMinter.mintByAdmin(_account, _USDTAmt);
    }

    /// @dev It calls burnByAdmin of BNIMinter.
    /// @param _pool total pool in USD
    /// @param _share amount of shares
    function burn(uint _pool, uint _share, bytes calldata _signature) external payable returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _pool, _share)), _signature);

        if (isLPChain) {
            bniMinter.burnByAdmin(account, _pool, _share);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                BNIUserAgentSub.burnByAdmin.selector,
                account, _pool, _share
            );
            _feeAmt = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData, false);
        }
        nonces[account] = _nonce + 1;
    }

    function burnByAdmin(address _account, uint _pool, uint _share) external onlyRole(ADAPTER_ROLE) {
        bniMinter.burnByAdmin(_account, _pool, _share);
    }

    /// @dev It calls withdrawPercByAdmin of BNIVaults.
    function withdraw(
        uint[] memory _chainIds, uint _sharePerc, uint _minterNonce, bytes calldata _signature
    ) external payable returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _chainIds, _sharePerc, _minterNonce)), _signature);

        for (uint i = 0; i < _chainIds.length; i ++) {
            _feeAmt += _withdraw(account, _chainIds[i], _sharePerc, _minterNonce);
        }
        nonces[account] = _nonce + 1;
    }

    function _withdraw(
        address _account, uint _chainId, uint _sharePerc, uint _minterNonce
    ) private returns (uint _feeAmt) {
        IBNIVault bniVault = bniVaults[_chainId];
        require(address(bniVault) != address(0), "Invalid bniVault");

        if (_chainId == Token.getChainID()) {
            bniVault.withdrawPercByAdmin(_account, _sharePerc, _minterNonce);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                BNIUserAgentSub.withdrawPercByAdmin.selector,
                _account, _sharePerc, _minterNonce
            );
            _feeAmt = _call(_chainId, userAgents[_chainId], 0, _targetCallData, false);
        }
    }

    function withdrawPercByAdmin(
        address _account, uint _sharePerc, uint _minterNonce
    ) external onlyRole(ADAPTER_ROLE) {
        IBNIVault bniVault = bniVaults[Token.getChainID()];
        uint balanceBefore = USDT.balanceOf(address(this));
        bniVault.withdrawPercByAdmin(_account, _sharePerc, _minterNonce);
        usdtBalances[_account] += (USDT.balanceOf(address(this)) - balanceBefore);
    }

    /// @dev It gathers withdrawn tokens of the user from user agents.
    function gather(
        uint[] memory _fromChainIds,
        AdapterType[] memory _adapterTypes,
        bytes calldata _signature
    ) external payable returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _fromChainIds, _adapterTypes)), _signature);

        for (uint i = 0; i < _fromChainIds.length; i ++) {
            _feeAmt += _gather(account, _fromChainIds[i], _adapterTypes[i]);
        }
        nonces[account] = _nonce + 1;
    }

    function _gather(
        address _account, uint _fromChainId, AdapterType _adapterType
    ) private returns (uint _feeAmt) {
        uint chainId = Token.getChainID();
        if (_fromChainId != chainId) {
            bytes memory _targetCallData = abi.encodeWithSelector(
                BNIUserAgentSub.gatherByAdmin.selector,
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

            uint feeAmt = _transfer(_account, Const.TokenID.USDT, amounts, toChainIds, toAddresses, adapterTypes, 1, true);
            uint tokensForFee = swap.getAmountsInForETH(address(USDT), feeAmt);
            if (balance > tokensForFee) {
                uint spentTokenAmount = swap.swapTokensForExactETH(address(USDT), tokensForFee, feeAmt);
                amounts[0] = balance - spentTokenAmount;
                usdtBalances[_account] = 0;

                _transfer(_account, Const.TokenID.USDT, amounts, toChainIds, toAddresses, adapterTypes, 1, false);
                emit Transfer(Token.getChainID(), address(USDT), balance, _toChainId, _account);
            }
        }
    }

    /// @dev It calls exitWithdrawalByAdmin of BNIMinter.
    /// @param _gatheredAmount is the amount of token that is gathered.
    /// @notice _gatheredAmount doesn't include the balance which is withdrawan in this agent.
    function exitWithdrawal(uint _gatheredAmount, bytes calldata _signature) external payable returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _gatheredAmount)), _signature);

        if (isLPChain) {
            bniMinter.exitWithdrawalByAdmin(account);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                BNIUserAgentSub.exitWithdrawalByAdmin.selector,
                account
            );
            _feeAmt = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData, false);
        }

        uint amount = _gatheredAmount + usdtBalances[account];
        usdtBalances[account] = 0;
        USDT.safeTransfer(account, amount);

        nonces[account] = _nonce + 1;
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
