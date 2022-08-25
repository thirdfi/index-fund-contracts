// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface ISwap {
    function swapExactTokensForTokens(address _tokenA, address _tokenB, uint _amt, uint _minAmount) external returns (uint);
    function swapExactTokensForTokens2(address _tokenA, address _tokenB, uint _amt, uint _minAmount) external returns (uint);

    function swapExactETHForTokens(address _tokenB, uint _amt, uint _minAmount) external payable returns (uint);
    function swapTokensForExactETH(address _tokenA, uint _amountInMax, uint _amountOut) external returns (uint _spentTokenAmount);
    function swapExactTokensForETH(address _tokenA, uint _amt, uint _minAmount) external returns (uint);

    function getAmountsInForETH(address _tokenA, uint _amountOut) external view returns (uint);
}
