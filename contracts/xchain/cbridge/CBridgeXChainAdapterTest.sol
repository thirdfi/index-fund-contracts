//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "../../../libs/Token.sol";
import "../BasicXChainAdapter.sol";
import "./CBridgeXChainAdapter.sol";

contract CBridgeXChainAdapterTest is CBridgeXChainAdapter {

    function initialize1(address _messageBus) external override initializer {
        BasicXChainAdapter.initialize();
        messageBus = _messageBus;
        USDC = IERC20Upgradeable(Token.getTestTokenAddress(Const.TokenID.USDC));
        USDT = IERC20Upgradeable(Token.getTestTokenAddress(Const.TokenID.USDT));
    }
}
