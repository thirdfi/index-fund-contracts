//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../../bni/constant/AvaxConstant.sol";
import "../../sti/ISTIMinter.sol";
import "../../sti/ISTIVault.sol";
import "../../swap/ISwap.sol";
import "./BasicUserAgent.sol";

contract STIUserAgent is BasicUserAgent {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint public chainIdOnLP;
    bool public isLPChain;

    ISTIMinter public stiMinter;
    // Map of STIVaults (chainId => STIVault).
    mapping(uint => ISTIVault) public stiVaults;

    event Transfer(uint fromChainId, address token, uint indexed amount, uint indexed toChainId, address indexed account);

    function initialize1(
        address _admin,
        ISwap _swap,
        IXChainAdapter _multichainAdapter, IXChainAdapter _cbridgeAdapter,
        ISTIMinter _stiMinter, ISTIVault _stiVault
    ) external initializer {
        super.initialize(_admin, _swap, _multichainAdapter, _cbridgeAdapter);

        uint chainId = Token.getChainID();
        chainIdOnLP = AvaxConstant.CHAINID;
        isLPChain = (chainIdOnLP == chainId);

        stiMinter = _stiMinter;
        stiVaults[chainId] = _stiVault;
    }

    function setSTIMinter(ISTIMinter _stiMinter) external onlyOwner {
        stiMinter = _stiMinter;
    }

    function setSTIVaults(uint[] memory _chainIds, ISTIVault[] memory _stiVaults) external onlyOwner {
        uint length = _chainIds.length;
        for (uint i = 0; i < length; i++) {
            uint chainId = _chainIds[i];
            require(chainId != 0, "Invalid chainID");
            stiVaults[chainId] = _stiVaults[i];
        }
    }

    /// @dev It calls initDepositByAdmin of STIMinter.
    /// @param _pool total pool in USD
    /// @param _USDTAmt USDT with 6 decimals to be deposited
    function initDeposit(uint _pool, uint _USDTAmt, bytes calldata _signature) external payable whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _pool, _USDTAmt, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

        if (isLPChain) {
            stiMinter.initDepositByAdmin(account, _pool, _USDTAmt);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                STIUserAgent.initDepositByAdmin.selector,
                account, _pool, _USDTAmt
            );
            _feeAmt = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData, AdapterType.CBridge, false);
        }
        nonces[account] = _nonce + 1;
    }

    function initDepositByAdmin(address _account, uint _pool, uint _USDTAmt) external onlyRole(ADAPTER_ROLE) {
        stiMinter.initDepositByAdmin(_account, _pool, _USDTAmt);
    }

    /// @dev It transfers tokens to user agents
    function transfer(
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        AdapterType[] memory _adapterTypes,
        bytes calldata _signature
    ) external payable whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _amounts, _toChainIds, _adapterTypes, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

        (address[] memory toAddresses, uint lengthOut) = transferIn(account, _amounts, _toChainIds, _adapterTypes);
        if (lengthOut > 0) {
            _feeAmt = _transfer(account, Const.TokenID.USDT, _amounts, _toChainIds, toAddresses, _adapterTypes, lengthOut, false);
        }
        nonces[account] = _nonce + 1;
    }

    function transferIn(
        address account,
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        AdapterType[] memory _adapterTypes
    ) private returns (address[] memory _toAddresses, uint _lengthOut) {
        uint length = _amounts.length;
        _toAddresses = new address[](length);
        uint chainId = Token.getChainID();
        uint amountOn;
        uint amountOut;
        for (uint i = 0; i < length; i ++) {
            uint amount = _amounts[i];
            uint toChainId = _toChainIds[i];
            if (toChainId == chainId) {
                require(address(stiVaults[chainId]) != address(0), "Invalid stiVault");
                amountOn += amount;
            } else {
                if (_lengthOut != i) {
                    _toChainIds[_lengthOut] = amount;
                    _toChainIds[_lengthOut] = toChainId;
                    _adapterTypes[_lengthOut] = _adapterTypes[i];

                    address toUserAgent = userAgents[toChainId];
                    require(toUserAgent != address(0), "Invalid user agent");
                    _toAddresses[_lengthOut] = toUserAgent;
                }
                _lengthOut ++;
                amountOut += amount;
            }
        }

        USDT.safeTransferFrom(account, address(this), amountOn + amountOut);
        usdtBalances[account] += amountOn;
    }

    /// @dev It calls depositByAdmin of STIVaults.
    function deposit(
        uint[] memory _toChainIds,
        address[] memory _tokens,
        uint[] memory _USDTAmts,
        uint _minterNonce,
        bytes calldata _signature
    ) external payable whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _toChainIds, _tokens, _USDTAmts, _minterNonce, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

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
        ISTIVault stiVault = stiVaults[_toChainId];
        require(address(stiVault) != address(0), "Invalid stiVault");

        if (_toChainId == Token.getChainID()) {
            uint balance = usdtBalances[_account];
            uint amountSum;
            for (uint i = 0; i < _USDTAmts.length; i ++) {
                amountSum += _USDTAmts[i];
            }
            require(balance >= amountSum, "Insufficient balance");
            usdtBalances[_account] = balance - amountSum;

            stiVault.depositByAdmin(_account, _tokens, _USDTAmts, _minterNonce);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                STIUserAgent.depositByAdmin.selector,
                _account, _tokens, _USDTAmts, _minterNonce
            );
            _feeAmt = _call(_toChainId, userAgents[_toChainId], 0, _targetCallData, AdapterType.CBridge, false);
        }
    }

    function depositByAdmin(
        address _account,
        address[] memory _tokens,
        uint[] memory _USDTAmts,
        uint _minterNonce
    ) external onlyRole(ADAPTER_ROLE) {
        ISTIVault stiVault = stiVaults[Token.getChainID()];
        stiVault.depositByAdmin(_account, _tokens, _USDTAmts, _minterNonce);
    }

    /// @dev It calls mintByAdmin of STIMinter.
    function mint(uint _USDTAmt, bytes calldata _signature) external payable whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _USDTAmt, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

        if (isLPChain) {
            stiMinter.mintByAdmin(account, _USDTAmt);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                STIUserAgent.mintByAdmin.selector,
                account, _USDTAmt
            );
            _feeAmt = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData, AdapterType.CBridge, false);
        }
        nonces[account] = _nonce + 1;
    }

    function mintByAdmin(address _account, uint _USDTAmt) external onlyRole(ADAPTER_ROLE) {
        stiMinter.mintByAdmin(_account, _USDTAmt);
    }

    /// @dev It calls burnByAdmin of STIMinter.
    /// @param _pool total pool in USD
    /// @param _share amount of shares
    function burn(uint _pool, uint _share, bytes calldata _signature) external payable returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _pool, _share, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

        if (isLPChain) {
            stiMinter.burnByAdmin(account, _pool, _share);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                STIUserAgent.burnByAdmin.selector,
                account, _pool, _share
            );
            _feeAmt = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData, AdapterType.CBridge, false);
        }
        nonces[account] = _nonce + 1;
    }

    function burnByAdmin(address _account, uint _pool, uint _share) external onlyRole(ADAPTER_ROLE) {
        stiMinter.burnByAdmin(_account, _pool, _share);
    }

    /// @dev It calls withdrawPercByAdmin of STIVaults.
    function withdraw(
        uint[] memory _chainIds, uint _sharePerc, uint _minterNonce, bytes calldata _signature
    ) external payable returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _chainIds, _sharePerc, _minterNonce, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

        for (uint i = 0; i < _chainIds.length; i ++) {
            _feeAmt += _withdraw(account, _chainIds[i], _sharePerc, _minterNonce);
        }
        nonces[account] = _nonce + 1;
    }

    function _withdraw(
        address _account, uint _chainId, uint _sharePerc, uint _minterNonce
    ) private returns (uint _feeAmt) {
        ISTIVault stiVault = stiVaults[_chainId];
        require(address(stiVault) != address(0), "Invalid stiVault");

        if (_chainId == Token.getChainID()) {
            stiVault.withdrawPercByAdmin(_account, _sharePerc, _minterNonce);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                STIUserAgent.withdrawPercByAdmin.selector,
                _account, _sharePerc, _minterNonce
            );
            _feeAmt = _call(_chainId, userAgents[_chainId], 0, _targetCallData, AdapterType.CBridge, false);
        }
    }

    function withdrawPercByAdmin(
        address _account, uint _sharePerc, uint _minterNonce
    ) external onlyRole(ADAPTER_ROLE) {
        ISTIVault stiVault = stiVaults[Token.getChainID()];
        uint balanceBefore = USDT.balanceOf(address(this));
        stiVault.withdrawPercByAdmin(_account, _sharePerc, _minterNonce);
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
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _fromChainIds, _adapterTypes, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

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
                STIUserAgent.gatherByAdmin.selector,
                _account, chainId, _adapterType
            );
            _feeAmt = _call(_fromChainId, userAgents[_fromChainId], 0, _targetCallData, AdapterType.CBridge, false);
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

    /// @dev It calls exitWithdrawalByAdmin of STIMinter.
    /// @param _gatheredAmount is the amount of token that is gathered.
    /// @notice _gatheredAmount doesn't include the balance which is withdrawan in this agent.
    function exitWithdrawal(uint _gatheredAmount, bytes calldata _signature) external payable returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _gatheredAmount, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

        if (isLPChain) {
            stiMinter.exitWithdrawalByAdmin(account);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                STIUserAgent.exitWithdrawalByAdmin.selector,
                account
            );
            _feeAmt = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData, AdapterType.CBridge, false);
        }

        uint amount = _gatheredAmount + usdtBalances[account];
        usdtBalances[account] = 0;
        USDT.safeTransfer(account, amount);

        nonces[account] = _nonce + 1;
    }

    function exitWithdrawalByAdmin(address _account) external onlyRole(ADAPTER_ROLE) {
        stiMinter.exitWithdrawalByAdmin(_account);
    }

    /// @dev It calls claimByAdmin of STIVaults.
    function claim(
        uint[] memory _chainIds, bytes calldata _signature
    ) external payable returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _chainIds, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

        for (uint i = 0; i < _chainIds.length; i ++) {
            _feeAmt += _claim(account, _chainIds[i]);
        }
        nonces[account] = _nonce + 1;
    }

    function _claim(address _account, uint _chainId) private returns (uint _feeAmt) {
        ISTIVault stiVault = stiVaults[_chainId];
        require(address(stiVault) != address(0), "Invalid stiVault");

        if (_chainId == Token.getChainID()) {
            stiVault.claimByAdmin(_account);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                STIUserAgent.claimByAdmin.selector,
                _account
            );
            _feeAmt = _call(_chainId, userAgents[_chainId], 0, _targetCallData, AdapterType.CBridge, false);
        }
    }

    function claimByAdmin(address _account) external onlyRole(ADAPTER_ROLE) {
        ISTIVault stiVault = stiVaults[Token.getChainID()];
        uint balanceBefore = USDT.balanceOf(address(this));
        stiVault.claimByAdmin(_account);
        usdtBalances[_account] += (USDT.balanceOf(address(this)) - balanceBefore);
    }

    /// @dev It takes out tokens from this agent.
    /// @param _gatheredAmount is the amount of token that is gathered.
    /// @notice _gatheredAmount doesn't include the balance which is withdrawan in this agent.
    function takeOut(uint _gatheredAmount, bytes calldata _signature) external {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _gatheredAmount, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

        uint amount = _gatheredAmount + usdtBalances[account];
        usdtBalances[account] = 0;
        USDT.safeTransfer(account, amount);

        nonces[account] = _nonce + 1;
    }
}
