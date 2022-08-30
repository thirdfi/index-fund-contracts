//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
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
        CBridge,
        Multichain
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
        Const.TokenID _tokenId,
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        address[] memory _toAddresses,
        AdapterType[] memory _adapterTypes,
        uint _length,
        bool _skim // It's a flag to calculate fee without execution
    ) internal returns (uint _feeAmt) {
        (uint[] memory mchainAmounts, uint[] memory mchainToChainIds, address[] memory mchainToAddresses,
        uint[] memory cbridgeAmounts, uint[] memory cbridgeToChainIds, address[] memory cbridgeToAddresses)
            = splitTranfersPerAdapter(_amounts, _toChainIds, _toAddresses, _adapterTypes, _length);

        if (_skim == false && mchainAmounts.length > 0) {
            transferThroughMultichain(_from, _tokenId, mchainAmounts, mchainToChainIds, mchainToAddresses);
        }
        if (cbridgeAmounts.length > 0) {
            _feeAmt = transferThroughCBridge(_from, _tokenId, cbridgeAmounts, cbridgeToChainIds, cbridgeToAddresses, _skim);
        }
    }

    function transferThroughMultichain (
        address _from,
        Const.TokenID _tokenId,
        uint[] memory _mchainAmounts,
        uint[] memory _mchainToChainIds,
        address[] memory _mchainToAddresses
    ) private {
        uint mchainReqCount = _mchainAmounts.length;
        multichainAdapter.transfer(_tokenId, _mchainAmounts, _mchainToChainIds, _mchainToAddresses);

        uint chainId = Token.getChainID();
        for (uint i = 0; i < mchainReqCount; i ++) {
            emit Transfer(_from, address(USDT), _mchainAmounts[i], chainId, _mchainToChainIds[i], _mchainToAddresses[i], AdapterType.Multichain, 0);
        }
    }

    function transferThroughCBridge (
        address _from,
        Const.TokenID _tokenId,
        uint[] memory _cbridgeAmounts,
        uint[] memory _cbridgeToChainIds,
        address[] memory _cbridgeToAddresses,
        bool _skim // It's a flag to calculate fee without execution
    ) private returns (uint _feeAmt) {
        uint cbridgeReqCount = _cbridgeAmounts.length;
        _feeAmt = cbridgeAdapter.calcTransferFee() * cbridgeReqCount;

        if (_skim == false && address(this).balance >= _feeAmt) {
            uint cbridgeNonce = ICBridgeAdapter(address(cbridgeAdapter)).nonce();
            cbridgeAdapter.transfer{value: _feeAmt}(_tokenId, _cbridgeAmounts, _cbridgeToChainIds, _cbridgeToAddresses);

            uint chainId = Token.getChainID();
            for (uint i = 0; i < cbridgeReqCount; i ++) {
                uint nonce = cbridgeNonce + i;
                cbridgeSenders[nonce] = _from;
                emit Transfer(_from, address(USDT), _cbridgeAmounts[i], chainId, _cbridgeToChainIds[i], _cbridgeToAddresses[i], AdapterType.CBridge, nonce);
            }
        }
    }

    function splitTranfersPerAdapter (
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        address[] memory _toAddresses,
        AdapterType[] memory _adapterTypes,
        uint length
    ) private pure returns (
        uint[] memory _mchainAmounts,
        uint[] memory _mchainToChainIds,
        address[] memory _mchainToAddresses,
        uint[] memory _cbridgeAmounts,
        uint[] memory _cbridgeToChainIds,
        address[] memory _cbridgeToAddresses
    ){
        uint mchainReqCount;
        uint cbridgeReqCount;
        for (uint i = 0; i < length; i ++) {
            if (_adapterTypes[i] == AdapterType.Multichain) mchainReqCount ++;
            else if (_adapterTypes[i] == AdapterType.CBridge) cbridgeReqCount ++;
        }

        _mchainAmounts = new uint[](mchainReqCount);
        _mchainToChainIds = new uint[](mchainReqCount);
        _mchainToAddresses = new address[](mchainReqCount);
        _cbridgeAmounts = new uint[](cbridgeReqCount);
        _cbridgeToChainIds = new uint[](cbridgeReqCount);
        _cbridgeToAddresses = new address[](cbridgeReqCount);

        mchainReqCount = 0;
        cbridgeReqCount = 0;
        for (uint i = 0; i < length; i ++) {
            if (_adapterTypes[i] == AdapterType.Multichain) {
                _mchainAmounts[mchainReqCount] = _amounts[i];
                _mchainToChainIds[mchainReqCount] = _toChainIds[i];
                _mchainToAddresses[mchainReqCount] = _toAddresses[i];
                mchainReqCount ++;
            } else if (_adapterTypes[i] == AdapterType.CBridge) {
                _cbridgeAmounts[cbridgeReqCount] = _amounts[i];
                _cbridgeToChainIds[cbridgeReqCount] = _toChainIds[i];
                _cbridgeToAddresses[cbridgeReqCount] = _toAddresses[i];
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
        bool _skim // It's a flag to calculate fee without execution
    ) internal returns (uint _feeAmt) {
        require(_targetContract != address(0), "Invalid targetContract");
        IXChainAdapter adapter = (callAdapterTypes[_toChainId] == AdapterType.Multichain) ? multichainAdapter : cbridgeAdapter;

        _feeAmt = adapter.calcCallFee(_toChainId, _targetContract, _targetCallValue, _targetCallData);
        if (_skim == false && address(this).balance >= _feeAmt) {
            adapter.call{value: _feeAmt}(_toChainId, _targetContract, _targetCallValue, _targetCallData);
        }
    }

    receive() external payable {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[39] private __gap;
}
