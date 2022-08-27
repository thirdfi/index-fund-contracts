// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISTIVault {
    function depositByAdmin(address _account, address[] memory _tokens, uint[] memory _USDTAmts, uint _nonce) external;
    function depositByAgent(address _account, address[] memory _tokens, uint[] memory _USDTAmts, uint _nonce) external;
    function withdrawPercByAdmin(address _account, uint _sharePerc, uint _nonce) external;
    function withdrawPercByAgent(address _account, uint _sharePerc, uint _nonce) external;
    function claimByAdmin(address _account) external;
    function claimByAgent(address _account) external;
}