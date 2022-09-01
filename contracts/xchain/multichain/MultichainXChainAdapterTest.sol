//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "../../../libs/Token.sol";
import "../../bni/constant/EthConstantTest.sol";
import "../../bni/constant/FtmConstantTest.sol";
import "../BasicXChainAdapter.sol";
import "./MultichainXChainAdapter.sol";

contract MultichainXChainAdapterTest is MultichainXChainAdapter {

    IAnycallV6Proxy public anycallRouterTest;

    function initialize() public override initializer {
        BasicXChainAdapter.initialize();
        initAnycallProxy();
    }

    function initAnycallProxy() public onlyOwner {
        uint chainId = Token.getChainID();
        if (chainId == EthConstantTest.CHAINID) {
            anycallRouterTest = IAnycallV6Proxy(0x273a4fFcEb31B8473D51051Ad2a2EdbB7Ac8Ce02);
        } else if (chainId == FtmConstantTest.CHAINID) {
            anycallRouterTest = IAnycallV6Proxy(0xD7c295E399CA928A3a14b01D760E794f1AdF8990);
        } else {
            return;
        }

        anycallExecutor = IAnycallExecutor(anycallRouterTest.executor());
    }

    function call(
        uint _toChainId,
        address _targetContract,
        uint _targetCallValue,
        bytes memory _targetCallData
    ) external payable override onlyRole(CLIENT_ROLE) {
        if (address(anycallRouterTest) == address(0)) return;
        address peer = peers[_toChainId];
        require(peer != address(0), "No peer");

        bytes memory message = abi.encode(_targetContract, _targetCallValue, _targetCallData);
        anycallRouterTest.anyCall{value: msg.value}(peer, message, address(0), _toChainId, FLAG_PAY_FEE_ON_SRC);
    }

    function calcCallFee(
        uint _toChainId,
        address _targetContract,
        uint _targetCallValue,
        bytes memory _targetCallData
    ) public view override returns (uint) {
        if (address(anycallRouterTest) == address(0)) return 0;

        bytes memory message = abi.encode(_targetContract, _targetCallValue, _targetCallData);
        return anycallRouterTest.calcSrcFees("", _toChainId, message.length);
    }
}
