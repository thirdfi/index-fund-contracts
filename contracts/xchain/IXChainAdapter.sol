// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../libs/Const.sol";

interface IXChainAdapter {

    function transfer(
        uint8 _tokenId, // Const.TokenID
        uint[] memory _amounts,
        address _from,
        uint[] memory _toChainIds,
        address[] memory _toAddresses
    ) external payable;

    function call(
        uint _toChainId,
        address _targetContract,
        uint _targetCallValue,
        bytes memory _targetCallData
    ) external payable;

    function calcMessageFee(
        uint _toChainId,
        bytes memory _targetCallData
    ) external view returns (uint);
}
