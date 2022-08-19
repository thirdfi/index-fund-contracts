// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../../interfaces/IGnosisSafe.sol";
import "../Token.sol";
import "./Signature.sol";

contract GnosisSafeUpgradeable is Initializable {
    using AddressUpgradeable for address;

    // keccak256("EIP712Domain(uint256 chainId,address verifyingContract)")
    bytes32 constant DOMAIN_SEPARATOR_TYPEHASH = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    bytes32 separator;

    function __GnosisSafe_init() internal onlyInitializing {
        separator = domainSeparator();
    }

    /**
     * @dev Checks whether the signature provided is valid for the provided data, hash. Will revert otherwise.
     * @param dataHash Hash of the data (could be either a message hash or transaction hash)
     * @param data That should be signed (this is passed to an external validator contract)
     * @param signatures Signature data that should be verified. Can be ECDSA signature, contract signature (EIP-1271) or approved hash.
     */
    function checkSignatures(
        IGnosisSafe safe,
        bytes32 dataHash,
        bytes memory data,
        bytes memory signatures
    ) internal view returns (bool) {
        // Load threshold to avoid multiple storage loads
        uint256 _threshold = safe.getThreshold();
        // Check that a threshold is set
        if (_threshold == 0) return false;
        return checkNSignatures(safe, dataHash, data, signatures, _threshold);
    }

    function isAddressIncluded(address[] memory items, address item) internal pure returns (bool) {
        uint length = items.length;
        for (uint i = 0; i < length; i++) {
            if (items[i] == item) return true;
        }
        return false;
    }

    /**
     * @dev Checks whether the signature provided is valid for the provided data, hash. Will revert otherwise.
     * @param dataHash Hash of the data (could be either a message hash or transaction hash)
     * @param data That should be signed (this is passed to an external validator contract)
     * @param signatures Signature data that should be verified. Can be ECDSA signature, contract signature (EIP-1271) or approved hash.
     * @param requiredSignatures Amount of required valid signatures.
     */
    function checkNSignatures(
        IGnosisSafe safe,
        bytes32 dataHash,
        bytes memory data,
        bytes memory signatures,
        uint256 requiredSignatures
    ) internal view returns (bool) {
        // Check that the provided signature data is not too short
        if (signatures.length < (requiredSignatures*65)) return false;
        address currentOwner;
        address[] memory owners = safe.getOwners();
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 i;

        for (i = 0; i < requiredSignatures; i++) {
            (v, r, s) = Signature.signatureSplit(signatures, i);
            if (v == 0) {
                // If v is 0 then it is a contract signature
                // When handling contract signatures the address of the contract is encoded into r
                currentOwner = address(uint160(uint256(r)));

                // Check that signature data pointer (s) is not pointing inside the static part of the signatures bytes
                // This check is not completely accurate, since it is possible that more signatures than the threshold are send.
                // Here we only check that the pointer is not pointing inside the part that is being processed
                if (uint256(s) < (requiredSignatures*65)) return false;

                // Check that signature data pointer (s) is in bounds (points to the length of data -> 32 bytes)
                if((uint256(s) + 32) > signatures.length) return false;

                // Check if the contract signature is in bounds: start of data is s + 32 and end is start + signature length
                uint256 contractSignatureLen;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    contractSignatureLen := mload(add(add(signatures, s), 0x20))
                }
                if((uint256(s) + 32 + contractSignatureLen) > signatures.length) return false;

                // Check signature
                bytes memory contractSignature;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    // The signature data for contract signatures is appended to the concatenated signatures and the offset is stored in s
                    contractSignature := add(add(signatures, s), 0x20)
                }
                if (_isValidSignature(IGnosisSafe(currentOwner), data, contractSignature) == false) return false;
            } else {
                // Default is the ecrecover flow with the provided data hash
                // Use ecrecover with the messageHash for EOA signatures
                currentOwner = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)), v, r, s);
            }
            if (isAddressIncluded(owners, currentOwner) == false) return false;
        }
        return true;
    }

    /**
     * Implementation of ISignatureValidator (see `interfaces/ISignatureValidator.sol`)
     * @dev Should return whether the signature provided is valid for the provided data.
     * @param _data Arbitrary length data signed on the behalf of address(msg.sender)
     * @param _signature Signature byte array associated with _data
     * @return a bool upon valid or invalid signature with corresponding _data
     */
    function _isValidSignature(IGnosisSafe _safe, bytes memory _data, bytes memory _signature) internal view returns (bool) {
        bytes32 dataHash = getMessageHashForSafe(_data);
        return checkSignatures(_safe, dataHash, _data, _signature);
    }

    function isValidSignature(address _account, bytes memory _data, bytes calldata _signature) public view returns (bool) {
        bytes32 dataHash = getMessageHashForSafe(_data);
        if (_account.isContract()) {
            return checkSignatures(IGnosisSafe(_account), dataHash, _data, _signature);
        } else {
            (uint8 v, bytes32 r, bytes32 s) = Signature.signatureSplit(_signature, 0);
            bytes32 messageDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
            address signer = ecrecover(messageDigest, v, r, s);
            return (signer == _account);
        }
    }


    /// @dev Returns hash of a message that can be signed by owners.
    /// @param message Message that should be hashed
    /// @return Message hash.
    function getMessageHashForSafe(bytes memory message) public view returns (bytes32) {
        bytes32 safeMessageHash = keccak256(message);
        return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), separator, safeMessageHash));
    }

    function domainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, Token.getChainID(), address(this)));
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
