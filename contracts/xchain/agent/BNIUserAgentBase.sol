//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "../../bni/IBNIMinter.sol";
import "../../bni/IBNIVault.sol";
import "./BasicUserAgentBase.sol";

contract BNIUserAgentBase is BasicUserAgentBase {

    uint public chainIdOnLP;
    bool public isLPChain;

    IBNIMinter public bniMinter;
    IBNIVault public bniVault;

    // Address of sub-implementation contract
    address public subImpl;
}
