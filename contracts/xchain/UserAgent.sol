//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../../interfaces/IGnosisSafe.sol";
import "../../libs/multiSig/GnosisSafeUpgradeable.sol";

contract UserAgent is
    GnosisSafeUpgradeable,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    mapping(address => uint) public nonces;

    function initialize() public virtual initializer {
        __GnosisSafe_init();
    }

    function isValidFunctionCall(address _account, uint _value1, uint _nonce, bytes calldata _signature) public view returns (bool) {
        require(nonces[_account] == _nonce, "Invalid nonce");
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(_value1, _nonce)));
        return isValidSignature(_account, data, _signature);
    }

    receive() external payable {}
}
