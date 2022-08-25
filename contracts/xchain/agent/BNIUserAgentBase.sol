//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "../../bni/IBNIMinter.sol";
import "../../bni/IBNIVault.sol";
import "./BasicUserAgentBase.sol";

contract BNIUserAgentBase is BasicUserAgentBase {

    uint public chainIdOnLP;
    bool public isLPChain;

    IBNIMinter public bniMinter;
    // Map of BNIVaults (chainId => BNIVault).
    mapping(uint => IBNIVault) public bniVaults;

    // Address of sub-implementation contract
    address public subImpl;

    event Transfer(uint fromChainId, address token, uint indexed amount, uint indexed toChainId, address indexed account);
}
