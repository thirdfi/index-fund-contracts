//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../../interfaces/IGnosisSafe.sol";
import "../../libs/GnosisSafe.sol";

contract UserAgent is
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    using AddressUpgradeable for address;

    mapping(address => uint) public nonces;

    function initialize() public virtual initializer {
    }

    function getMessageHashForSafe(address _account, bytes memory _data) public view returns (bytes32) {
        bytes memory message = abi.encode(_data, nonces[_account]);
        return GnosisSafe.getMessageHashForSafe(message);
    }

    function isValidSignature(address _account, bytes calldata _data, bytes calldata _signature) public view returns (bool) {
        bytes32 dataHash = getMessageHashForSafe(_account, _data);
        if (_account.isContract()) {
            return GnosisSafe.checkSignatures(IGnosisSafe(_account), dataHash, _data, _signature);
        } else {
            (uint8 v, bytes32 r, bytes32 s) = GnosisSafe.signatureSplit(_signature, 0);
            bytes32 messageDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
            address signer = ecrecover(messageDigest, v, r, s);
            return (signer == _account);
        }
    }

    receive() external payable {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
