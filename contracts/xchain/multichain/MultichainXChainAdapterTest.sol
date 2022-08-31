//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "../BasicXChainAdapter.sol";
import "./MultichainXChainAdapter.sol";

contract MultichainXChainAdapterTest is MultichainXChainAdapter {

    function initialize() public override initializer {
        BasicXChainAdapter.initialize();
    }

    function call(
        uint, // _toChainId
        address, // _targetContract
        uint, // _targetCallValue
        bytes memory // _targetCallData
    ) external payable override onlyRole(CLIENT_ROLE) {
    }

    function calcCallFee(
        uint, // _toChainId
        address, // _targetContract
        uint, // _targetCallValue
        bytes memory // _targetCallData
    ) public view override returns (uint) {
        return 0;
    }
}
