// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ICurvePool {
    function exchange(int128 i, int128 j, uint dx, uint min_dy) external;
    function remove_liquidity_one_coin(uint amount, int128 index, uint amountOutMin) external;
    function get_virtual_price() external view returns (uint); // Precision is 18
}

interface ICurvePool_coin2 {
    function add_liquidity(uint[2] memory amounts, uint amountOutMin) external;
}

interface ICurvePool_coin3 {
    function add_liquidity(uint[3] memory amounts, uint amountOutMin) external;
}

interface ICurvePool_V2 {
    function remove_liquidity_one_coin(uint amount, uint index, uint amountOutMin) external;
}
