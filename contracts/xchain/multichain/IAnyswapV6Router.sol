//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

// https://github.com/anyswap/anyswap-v1-core/blob/d5f40f9a29212f597149f3cee9f8d9df1b108a22/contracts/AnyswapV6Router.sol
interface IAnyswapV6Router {
    function anySwapOut(address token, address to, uint amount, uint toChainID) external;
    function anySwapOutUnderlying(address token, address to, uint amount, uint toChainID) external;
    function anySwapOutNative(address token, address to, uint toChainID) external payable;
    function anySwapOut(address[] calldata tokens, address[] calldata to, uint[] calldata amounts, uint[] calldata toChainIDs) external;
    function anySwapOut(address token, string memory to, uint amount, uint toChainID) external;
    function anySwapOutUnderlying(address token, string memory to, uint amount, uint toChainID) external;
    function depositNative(address token, address to) external payable returns (uint);
    function withdrawNative(address token, uint amount, address to) external returns (uint);

    function anySwapOutExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        uint toChainID
    ) external;

    function anySwapOutExactTokensForTokensUnderlying(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        uint toChainID
    ) external;

    function anySwapOutExactTokensForNative(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        uint toChainID
    ) external;

    function anySwapOutExactTokensForNativeUnderlying(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        uint toChainID
    ) external;
}
