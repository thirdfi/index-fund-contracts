//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

interface IGnosisSafe {
    function getThreshold() external view returns (uint);
    function isOwner(address owner) external view returns (bool);
    function getOwners() external view returns (address[] memory);
}
