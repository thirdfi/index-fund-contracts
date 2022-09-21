//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "sgn-v2-contracts/contracts/message/interfaces/IMessageReceiverApp.sol";
import "../../../libs/multiSig/GnosisSafeUpgradeable.sol";
import "../../../libs/BaseRelayRecipient.sol";
import "../../../libs/Const.sol";
import "../../swap/ISwap.sol";
import "../IXChainAdapter.sol";

interface ICBridgeAdapter is IXChainAdapter {
    function nonce() external view returns (uint);
}

contract BasicUserAgentBase is
    BaseRelayRecipient,
    GnosisSafeUpgradeable,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    enum AdapterType {
        Multichain, // Default adapter
        CBridge
    }

    struct TransfersPerAdapter {
        uint[] mchainAmounts;
        uint[] mchainToChainIds;
        address[] mchainToAddresses;
        uint[] cbridgeAmounts;
        uint[] cbridgeToChainIds;
        address[] cbridgeToAddresses;
    }

    bytes32 public constant ADAPTER_ROLE = keccak256("ADAPTER_ROLE");

    address public admin;
    mapping(address => uint) public nonces;

    ISwap swap;
    IERC20Upgradeable public USDC;
    IERC20Upgradeable public USDT;
    // These stores the balance that is deposited directly, not cross-transferred.
    // And these also store the refunded amount.
    mapping(address => uint) public usdcBalances;
    mapping(address => uint) public usdtBalances;

    IXChainAdapter public multichainAdapter;
    IXChainAdapter public cbridgeAdapter;
    // Map of transfer addresses (cbridgeAdapter's nonce => sender)
    mapping(uint => address) public cbridgeSenders;

    // Map of user agents (chainId => userAgent).
    mapping(uint => address) public userAgents;

    // Map of adapter types for calling (chainId => AdapterType).
    // AdapterType.CBridge is the default adapter because it is 0.
    mapping(uint => AdapterType) public callAdapterTypes;

    // Map of gas amounts (function signature => gas amount).
    mapping(bytes4 => uint) public gasAmounts;
    // Map of gas prices (chainId => gas cost in the native token of the current chain).
    mapping(uint => uint) public gasCosts;

    address public treasuryWallet;

    event Transfer(
        address indexed from,
        address token,
        uint indexed amount,
        uint fromChainId,
        uint indexed toChainId,
        address to,
        AdapterType adapterType,
        uint nonce
    );

    function _msgSender() internal override(ContextUpgradeable, BaseRelayRecipient) view returns (address) {
        return BaseRelayRecipient._msgSender();
    }

    function versionRecipient() external pure override returns (string memory) {
        return "1";
    }

    function checkSignature(bytes32 data, bytes calldata _signature) view internal {
        require(isValidSignature(admin, abi.encodePacked(data), _signature), "Invalid signature");
    }

    function _transfer(
        address _from,
        address _token,
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        address[] memory _toAddresses,
        AdapterType[] memory _adapterTypes,
        uint _length,
        uint _suppliedFee,
        bool _skim // It's a flag to calculate fee without execution
    ) internal returns (uint _feeAmt, uint _leftFee) {
        _leftFee = _suppliedFee;
        TransfersPerAdapter memory transfers = splitTranfersPerAdapter(_amounts, _toChainIds, _toAddresses, _adapterTypes, _length);

        if (_skim == false && transfers.mchainAmounts.length > 0) {
            transferThroughMultichain(_from, _token, transfers);
        }
        if (transfers.cbridgeAmounts.length > 0) {
            (_feeAmt, _leftFee) = transferThroughCBridge(_from, _token, transfers, _leftFee, _skim);
        }
    }

    function transferThroughMultichain (
        address _from,
        address _token,
        TransfersPerAdapter memory _transfers
    ) private {
        uint mchainReqCount = _transfers.mchainAmounts.length;
        multichainAdapter.transfer(_token, _transfers.mchainAmounts, _transfers.mchainToChainIds, _transfers.mchainToAddresses);

        uint chainId = Token.getChainID();
        for (uint i = 0; i < mchainReqCount; i ++) {
            emit Transfer(_from, _token, _transfers.mchainAmounts[i], chainId, _transfers.mchainToChainIds[i], _transfers.mchainToAddresses[i], AdapterType.Multichain, 0);
        }
    }

    function transferThroughCBridge (
        address _from,
        address _token,
        TransfersPerAdapter memory _transfers,
        uint _suppliedFee,
        bool _skim // It's a flag to calculate fee without execution
    ) private returns (uint _feeAmt, uint _leftFee) {
        _leftFee = _suppliedFee;
        uint cbridgeReqCount = _transfers.cbridgeAmounts.length;
        uint protocolFee = cbridgeAdapter.calcTransferFee() * cbridgeReqCount;
        _feeAmt = protocolFee + (gasAmounts[IMessageReceiverApp.executeMessageWithTransferRefund.selector] * gasCosts[Token.getChainID()] * cbridgeReqCount);

        if (_skim == false && _leftFee >= _feeAmt) {
            _leftFee -= _feeAmt;
            _transferThroughCBridge(_from, _token, _transfers, protocolFee);
        }
    }

    function _transferThroughCBridge (
        address _from,
        address _token,
        TransfersPerAdapter memory _transfers,
        uint _protocolFee
    ) private {
        uint cbridgeNonce = ICBridgeAdapter(address(cbridgeAdapter)).nonce();
        cbridgeAdapter.transfer{value: _protocolFee}(_token, _transfers.cbridgeAmounts, _transfers.cbridgeToChainIds, _transfers.cbridgeToAddresses);

        uint chainId = Token.getChainID();
        for (uint i = 0; i < _transfers.cbridgeAmounts.length; i ++) {
            uint nonce = cbridgeNonce + i;
            cbridgeSenders[nonce] = _from;
            emit Transfer(_from, _token, _transfers.cbridgeAmounts[i], chainId, _transfers.cbridgeToChainIds[i], _transfers.cbridgeToAddresses[i], AdapterType.CBridge, nonce);
        }
    }

    function splitTranfersPerAdapter (
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        address[] memory _toAddresses,
        AdapterType[] memory _adapterTypes,
        uint length
    ) private pure returns (TransfersPerAdapter memory _transfers) {
        uint mchainReqCount;
        uint cbridgeReqCount;
        for (uint i = 0; i < length; i ++) {
            if (_adapterTypes[i] == AdapterType.Multichain) mchainReqCount ++;
            else if (_adapterTypes[i] == AdapterType.CBridge) cbridgeReqCount ++;
        }

        _transfers = TransfersPerAdapter({
            mchainAmounts: new uint[](mchainReqCount),
            mchainToChainIds: new uint[](mchainReqCount),
            mchainToAddresses: new address[](mchainReqCount),
            cbridgeAmounts: new uint[](cbridgeReqCount),
            cbridgeToChainIds: new uint[](cbridgeReqCount),
            cbridgeToAddresses: new address[](cbridgeReqCount)
        });

        mchainReqCount = 0;
        cbridgeReqCount = 0;
        for (uint i = 0; i < length; i ++) {
            if (_adapterTypes[i] == AdapterType.Multichain) {
                _transfers.mchainAmounts[mchainReqCount] = _amounts[i];
                _transfers.mchainToChainIds[mchainReqCount] = _toChainIds[i];
                _transfers.mchainToAddresses[mchainReqCount] = _toAddresses[i];
                mchainReqCount ++;
            } else if (_adapterTypes[i] == AdapterType.CBridge) {
                _transfers.cbridgeAmounts[cbridgeReqCount] = _amounts[i];
                _transfers.cbridgeToChainIds[cbridgeReqCount] = _toChainIds[i];
                _transfers.cbridgeToAddresses[cbridgeReqCount] = _toAddresses[i];
                cbridgeReqCount ++;
            } else {
                revert("Invalid adapter type");
            }
        }
    }

    function _call(
        uint _toChainId,
        address _targetContract,
        uint _targetCallValue,
        bytes memory _targetCallData,
        bytes4 _targetFuncSelector,
        uint _suppliedFee,
        bool _skim // It's a flag to calculate fee without execution
    ) internal returns (uint _feeAmt, uint _leftFee) {
        _leftFee = _suppliedFee;
        require(_targetContract != address(0), "Invalid targetContract");
        IXChainAdapter adapter = (callAdapterTypes[_toChainId] == AdapterType.Multichain) ? multichainAdapter : cbridgeAdapter;

        uint protocolFee = adapter.calcCallFee(_toChainId, _targetContract, _targetCallValue, _targetCallData);
        _feeAmt = protocolFee;
        if (adapter == cbridgeAdapter) {
            _feeAmt += (gasAmounts[_targetFuncSelector] * gasCosts[_toChainId]);
        }

        if (_skim == false && _leftFee >= _feeAmt) {
            _leftFee -= _feeAmt;
            adapter.call{value: protocolFee}(_toChainId, _targetContract, _targetCallValue, _targetCallData);
        }
    }

    function minTransfer(
        address _token,
        uint _toChainId,
        AdapterType _adapterType
    ) public view returns (uint) {
        return (_adapterType == AdapterType.Multichain)
                ? multichainAdapter.minTransfer(_token, _toChainId)
                : cbridgeAdapter.minTransfer(_token, _toChainId);
    }

    receive() external payable {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[35] private __gap; // NOTE Change it with one more amount when it is deployed on testnet
}
