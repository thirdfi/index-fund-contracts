//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

// https://github.com/anyswap/anyswap-v1-core/blob/master/contracts/AnyswapV6CallProxy.sol

interface IAnycallExecutor {
    function context() external returns (address from, uint256 fromChainID, uint256 nonce);

    function execute(
        address _to,
        bytes calldata _data,
        address _from,
        uint256 _fromChainID,
        uint256 _nonce,
        bool _isFallBack
    ) external returns (bool success, bytes memory result);
}

interface IAnycallV6Proxy {
    function executor() external view returns (address);

    function anyCall(
        address _to,
        bytes calldata _data,
        address _fallback,
        uint _toChainID,
        uint _flags
    ) external payable;

    function calcSrcFees(
        string calldata _appID,
        uint _toChainID,
        uint _dataLength
    ) external view returns (uint);
}
