// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IXChainAdapter {

    function transfer(
        address _token,
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        address[] memory _toAddresses
    ) external payable;

    function call(
        uint _toChainId,
        address _targetContract,
        uint _targetCallValue,
        bytes memory _targetCallData
    ) external payable;

    function calcTransferFee() external view returns (uint);

    function calcCallFee(
        uint _toChainId,
        address _targetContract,
        uint _targetCallValue,
        bytes memory _targetCallData
    ) external view returns (uint);

    function minTransfer(
        address _token,
        uint _toChainId
    ) external view returns (uint);
}
