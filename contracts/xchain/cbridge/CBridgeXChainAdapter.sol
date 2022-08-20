//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../BasicXChainAdapter.sol";
import "./MessageReceiverApp.sol";
import "./MessageSenderApp.sol";

contract CBridgeXChainAdapter is MessageSenderApp, MessageReceiverApp, BasicXChainAdapter {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct TransferRequest {
        uint64 nonce;
        address[] accounts;
        uint256[] amounts;
        address sender;
    }

    function initialize(address _messageBus) public initializer {
        super.initialize();
        messageBus = _messageBus;
    }

    function transferOwnership(address newOwner) public virtual override(OwnableUpgradeable, BasicXChainAdapter) onlyOwner {
        BasicXChainAdapter.transferOwnership(newOwner);
    }

    // called on source chain for handling of bridge failures (bad liquidity, bad slippage, etc...)
    function executeMessageWithTransferRefund(
        address _token,
        uint256 _amount,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        return ExecutionStatus.Success;
    }

    // ============== functions on destination chain ==============

    // handler function required by MsgReceiverApp
    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes memory _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        return ExecutionStatus.Success;
    }

    // handler function required by MsgReceiverApp
    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        return ExecutionStatus.Success;
    }

    // handler function required by MsgReceiverApp
    // called only if handleMessageWithTransfer above was reverted
    function executeMessageWithTransferFallback(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        return ExecutionStatus.Success;
    }
}
