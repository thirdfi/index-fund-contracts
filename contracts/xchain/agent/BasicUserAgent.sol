//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../../../libs/multiSig/GnosisSafeUpgradeable.sol";
import "../IXChainAdapter.sol";
import "./IUserAgent.sol";

contract BasicUserAgent is
    IUserAgent,
    GnosisSafeUpgradeable,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    enum Adapter {
        Multichain,
        CBridge
    }

    mapping(address => uint) public nonces;

    IXChainAdapter public multichainAdapter;
    IXChainAdapter public cbridgeAdapter;

    modifier onlyCBridgeAdapter {
        require(msg.sender == address(cbridgeAdapter), "Only cBridge");
        _;
    }

    function initialize() public virtual initializer {
        __GnosisSafe_init();
    }

    function isValidFunctionCall(address _account, uint _value1, uint _nonce, bytes calldata _signature) public view returns (bool) {
        require(nonces[_account] == _nonce, "Invalid nonce");
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(_value1, _nonce)));
        return isValidSignature(_account, data, _signature);
    }

    function onRefunded(uint _nonce, address _token, uint amount, uint _toChainId, address _to) external onlyCBridgeAdapter {
    }

    function transfer(
        uint8 _tokenId,
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        address[] memory _toAddresses,
        uint8[] memory _adapterTypes
    ) internal {
        uint length = _amounts.length;
        uint mchainReqCount;
        uint cbridgeReqCount;
        for (uint i = 0; i < length; i ++) {
            if (_adapterTypes[i] == uint8(Adapter.Multichain)) mchainReqCount ++;
            else if (_adapterTypes[i] == uint8(Adapter.CBridge)) cbridgeReqCount ++;
        }

        uint[] memory mchainAmounts = new uint[](mchainReqCount);
        uint[] memory mchainToChainIds = new uint[](mchainReqCount);
        address[] memory mchainToAddresses = new address[](mchainReqCount);
        uint[] memory cbridgeAmounts = new uint[](cbridgeReqCount);
        uint[] memory cbridgeToChainIds = new uint[](cbridgeReqCount);
        address[] memory cbridgeToAddresses = new address[](cbridgeReqCount);

        mchainReqCount = 0;
        cbridgeReqCount = 0;
        for (uint i = 0; i < length; i ++) {
            if (_adapterTypes[i] == uint8(Adapter.Multichain)) {
                mchainAmounts[mchainReqCount] = _amounts[i];
                mchainToChainIds[mchainReqCount] = _toChainIds[i];
                mchainToAddresses[mchainReqCount] = _toAddresses[i];
                mchainReqCount ++;
            } else if (_adapterTypes[i] == uint8(Adapter.CBridge)) {
                cbridgeAmounts[cbridgeReqCount] = _amounts[i];
                cbridgeToChainIds[cbridgeReqCount] = _toChainIds[i];
                cbridgeToAddresses[cbridgeReqCount] = _toAddresses[i];
                cbridgeReqCount ++;
            }
        }

        if (mchainReqCount > 0) {
            multichainAdapter.transfer(_tokenId, mchainAmounts, mchainToChainIds, mchainToAddresses);
        }
        if (cbridgeReqCount > 0) {
            uint fee = cbridgeAdapter.calcTransferFee();
            cbridgeAdapter.transfer{value: fee * cbridgeReqCount}(_tokenId, cbridgeAmounts, cbridgeToChainIds, cbridgeToAddresses);
        }
    }

    receive() external payable {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
