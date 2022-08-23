//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

interface IUserAgent {
    function onRefunded(uint _nonce, address _token, uint amount, uint _toChainId, address _to) external;
}
