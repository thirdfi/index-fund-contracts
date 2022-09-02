//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

interface ICBridge {
    function minSend(address token) external view returns (uint);
    function maxSend(address token) external view returns (uint);
}
