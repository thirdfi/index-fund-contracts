//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../../bni/constant/AvaxConstant.sol";
import "../../sti/ISTIMinter.sol";
import "../../sti/ISTIVault.sol";
import "./BasicUserAgent.sol";

contract STIUserAgent is BasicUserAgent {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    ISTIMinter public stiMinter;
    // Map of STIVaults (chainId => STIVault).
    mapping(uint => ISTIVault) public stiVaults;

    function initialize1(
        address _admin,
        IXChainAdapter _multichainAdapter, IXChainAdapter _cbridgeAdapter,
        ISTIMinter _stiMinter, ISTIVault _stiVault
    ) external initializer {
        super.initialize(_admin, _multichainAdapter, _cbridgeAdapter);
        stiMinter = _stiMinter;
        stiVaults[Token.getChainID()] = _stiVault;
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

        uint chainId = Token.getChainID();
        if (chainId == AvaxConstant.CHAINID) {
            stiMinter.initDepositByAdmin(account, _pool, _USDTAmt);
        } else {
            address toUserAgent = userAgents[AvaxConstant.CHAINID];
            require(toUserAgent != address(0), "Invalid Avalanche user agent");
            bytes memory _targetCallData = abi.encodeWithSelector(
                STIUserAgent.initDepositByAdmin.selector,
                account, _pool, _USDTAmt
            );
            _feeAmt = call(AvaxConstant.CHAINID, toUserAgent, 0, _targetCallData, AdapterType.Multichain);
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
    ) external payable returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _amounts, _toChainIds, _adapterTypes, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

        (address[] memory toAddresses, uint lengthOut) = transferIn(account, _amounts, _toChainIds, _adapterTypes);
        if (lengthOut > 0) {
            _feeAmt = transfer(account, Const.TokenID.USDT, _toChainIds, _toChainIds, toAddresses, _adapterTypes, lengthOut);
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
    ) external payable returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _toChainIds, _tokens, _USDTAmts, _minterNonce, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

        (uint toChainId, address[] memory subTokens, uint[] memory subUSDTAmts, uint newPos)
            = nextChainData(_toChainIds, _tokens, _USDTAmts, 0);
        while (toChainId != 0) {
            _feeAmt += _deposit(account, toChainId, subTokens, subUSDTAmts, _minterNonce);
            (toChainId, subTokens, subUSDTAmts, newPos) = nextChainData(_toChainIds, _tokens, _USDTAmts, newPos);
        }

        nonces[account] = _nonce + 1;
    }

    function nextChainData (
        uint[] memory _toChainIds,
        address[] memory _tokens,
        uint[] memory _USDTAmts,
        uint pos
    ) private view returns (
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
            stiVault.depositByAdmin(_account, _tokens, _USDTAmts, _minterNonce);
        } else {
            address toUserAgent = userAgents[_toChainId];
            require(toUserAgent != address(0), "Invalid user agent");
            bytes memory _targetCallData = abi.encodeWithSelector(
                STIUserAgent.depositByAdmin.selector,
                _account, _tokens, _USDTAmts, _minterNonce
            );
            _feeAmt = call(AvaxConstant.CHAINID, toUserAgent, 0, _targetCallData, AdapterType.Multichain);
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
    function mint(bytes calldata _signature) external payable whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

        uint chainId = Token.getChainID();
        if (chainId == AvaxConstant.CHAINID) {
            stiMinter.mintByAdmin(account);
        } else {
            address toUserAgent = userAgents[AvaxConstant.CHAINID];
            require(toUserAgent != address(0), "Invalid Avalanche user agent");
            bytes memory _targetCallData = abi.encodeWithSelector(
                STIUserAgent.mintByAdmin.selector,
                account
            );
            _feeAmt = call(AvaxConstant.CHAINID, toUserAgent, 0, _targetCallData, AdapterType.Multichain);
        }
        nonces[account] = _nonce + 1;
    }

    function mintByAdmin(address _account) external onlyRole(ADAPTER_ROLE) {
        stiMinter.mintByAdmin(_account);
    }

}
