//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "../../sti/ISTIMinter.sol";
import "../../sti/ISTIVault.sol";
import "./BasicUserAgentBase.sol";

contract STIUserAgentBase is BasicUserAgentBase {

    uint public chainIdOnLP;
    bool public isLPChain;

    ISTIMinter public stiMinter;
    // Map of STIVaults (chainId => STIVault).
    mapping(uint => ISTIVault) public stiVaults;

    // Address of sub-implementation contract
    address public subImpl;
}
