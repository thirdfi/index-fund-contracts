//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "../BasicXChainAdapter.sol";
import "./MultichainXChainAdapter.sol";

contract MultichainXChainAdapterTest is MultichainXChainAdapter {

    function initialize() public override initializer {
        BasicXChainAdapter.initialize();

        // AnyswapMap.initMap(anyswapMap);
        
        // uint chainId = Token.getChainID();
        // AnyswapMap.Entry memory entry;
        // entry = anyswapMap[Const.TokenID.USDT][chainId];
        // IERC20Upgradeable(entry.underlying).safeApprove(entry.router, type(uint).max);
        // entry = anyswapMap[Const.TokenID.USDC][chainId];
        // IERC20Upgradeable(entry.underlying).safeApprove(entry.router, type(uint).max);

        // anycallExecutor = IAnycallExecutor(anycallRouter.executor());
    }

    function call(
        uint, // _toChainId
        address, // _targetContract
        uint, // _targetCallValue
        bytes memory // _targetCallData
    ) external payable override onlyRole(CLIENT_ROLE) {
        // address peer = peers[_toChainId];
        // require(peer != address(0), "No peer");

        // bytes memory message = abi.encode(_targetContract, _targetCallValue, _targetCallData);
        // anycallRouter.anyCall{value: msg.value}(peer, message, address(0), _toChainId, FLAG_PAY_FEE_ON_SRC);
    }

    function calcCallFee(
        uint, // _toChainId
        address, // _targetContract
        uint, // _targetCallValue
        bytes memory // _targetCallData
    ) public view override returns (uint) {
        return 0;
        // bytes memory message = abi.encode(_targetContract, _targetCallValue, _targetCallData);
        // return anycallRouter.calcSrcFees("", _toChainId, message.length);
    }
}
