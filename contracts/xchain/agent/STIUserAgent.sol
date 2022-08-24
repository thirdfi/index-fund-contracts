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
        ISTIMinter _stiMinter
    ) external initializer {
        super.initialize(_admin, _multichainAdapter, _cbridgeAdapter);
        stiMinter = _stiMinter;
    }

    function setSTIMinter(ISTIMinter _stiMinter) external onlyOwner {
        stiMinter = _stiMinter;
    }

    /// @param _USDTAmt USDT with 6 decimals to be deposited
    function initDeposit(uint _USDTAmt, bytes calldata _signature) external payable whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _USDTAmt, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

        uint chainId = Token.getChainID();
        if (chainId == AvaxConstant.CHAINID) {
            stiMinter.initDepositByAdmin(account, _USDTAmt);
        } else {
            address toUserAgent = userAgents[AvaxConstant.CHAINID];
            require(toUserAgent != address(0), "Invalid Avalanche user agent");
            bytes memory _targetCallData = abi.encodeWithSelector(STIUserAgent.initDepositByAdmin.selector, account, _USDTAmt);
            _feeAmt = call(AvaxConstant.CHAINID, toUserAgent, 0, _targetCallData, AdapterType.Multichain);
        }
        nonces[account] = _nonce + 1;
    }

    function initDepositByAdmin(address _account, uint _USDTAmt) external onlyRole(ADAPTER_ROLE) {
        stiMinter.initDepositByAdmin(_account, _USDTAmt);
    }

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
}
