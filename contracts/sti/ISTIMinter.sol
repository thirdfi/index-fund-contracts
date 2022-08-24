// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISTIMinter {
    function initDepositByAdmin(address _account, uint _pool, uint _USDTAmt) external;
    function mintByAdmin(address _account) external;
    function burnByAdmin(address _account, uint _pool, uint _share) external;
    function exitWithdrawalByAdmin(address _account) external;
}