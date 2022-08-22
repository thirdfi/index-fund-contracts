//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

interface IUserAgent {
    function onRefunded(address _adapter, address _token, uint _amount, uint _nonce) external;
}
