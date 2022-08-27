// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISTIMinter {
    function initDepositByAdmin(address _account, uint _pool, uint _USDT6Amt) external;
    function mintByAdmin(address _account, uint _USDT6Amt) external;
    function burnByAdmin(address _account, uint _pool, uint _share) external;
    function exitWithdrawalByAdmin(address _account) external;
}