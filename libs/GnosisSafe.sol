// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../interfaces/IGnosisSafe.sol";
import "./Token.sol";

library GnosisSafe {

    // keccak256("EIP712Domain(uint256 chainId,address verifyingContract)")
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    address private constant SENTINEL_OWNERS = address(0x1);

    //keccak256("SafeMessage(bytes message)")
    bytes32 private constant SAFE_MSG_TYPEHASH = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;

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
        // There cannot be an owner with address 0.
        address lastOwner = address(0);
        address currentOwner;
        address[] memory owners = safe.getOwners();
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 i;

        for (i = 0; i < requiredSignatures; i++) {
            (v, r, s) = signatureSplit(signatures, i);
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
                if (isValidSignature(IGnosisSafe(currentOwner), data, contractSignature) == false) return false;
            } else if (v > 30) {
                // If v > 30 then default va (27,28) has been adjusted for eth_sign flow
                // To support eth_sign and similar we adjust v and hash the messageHash with the Ethereum message prefix before applying ecrecover
                currentOwner = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)), v - 4, r, s);
            } else {
                // Default is the ecrecover flow with the provided data hash
                // Use ecrecover with the messageHash for EOA signatures
                currentOwner = ecrecover(dataHash, v, r, s);
            }
            if (currentOwner <= lastOwner || isAddressIncluded(owners, currentOwner) == false || currentOwner == SENTINEL_OWNERS) return false;
            lastOwner = currentOwner;
        }
        return true;
    }

    /// @dev divides bytes signature into `uint8 v, bytes32 r, bytes32 s`.
    /// @notice Make sure to perform a bounds check for @param pos, to avoid out of bounds access on @param signatures
    /// @param pos which signature to read. A prior bounds check of this parameter should be performed, to avoid out of bounds access
    /// @param signatures concatenated rsv signatures
    function signatureSplit(bytes memory signatures, uint256 pos) internal pure returns (
        uint8 v, bytes32 r, bytes32 s
    ) {
        // The signature format is a compact form of:
        //   {bytes32 r}{bytes32 s}{uint8 v}
        // Compact means, uint8 is not padded to 32 bytes.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let signaturePos := mul(0x41, pos)
            r := mload(add(signatures, add(signaturePos, 0x20)))
            s := mload(add(signatures, add(signaturePos, 0x40)))
            // Here we are loading the last 32 bytes, including 31 bytes
            // of 's'. There is no 'mload8' to do this.
            //
            // 'byte' is not working due to the Solidity parser, so lets
            // use the second best option, 'and'
            v := and(mload(add(signatures, add(signaturePos, 0x41))), 0xff)
        }
    }

    /**
     * Implementation of ISignatureValidator (see `interfaces/ISignatureValidator.sol`)
     * @dev Should return whether the signature provided is valid for the provided data.
     * @param _data Arbitrary length data signed on the behalf of address(msg.sender)
     * @param _signature Signature byte array associated with _data
     * @return a bool upon valid or invalid signature with corresponding _data
     */
    function isValidSignature(IGnosisSafe _safe, bytes memory _data, bytes memory _signature) internal view returns (bool) {
        bytes32 messageHash = getMessageHashForSafe(_data);
        return checkSignatures(_safe, messageHash, _data, _signature);
    }

    /// @dev Returns hash of a message that can be signed by owners.
    /// @param message Message that should be hashed
    /// @return Message hash.
    function getMessageHashForSafe(bytes memory message) internal view returns (bytes32) {
        bytes32 safeMessageHash = keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(message)));
        return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator(), safeMessageHash));
    }

    function domainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, Token.getChainID(), address(this)));
    }
}
