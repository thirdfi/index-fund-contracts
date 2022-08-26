//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "sgn-v2-contracts/contracts/message/interfaces/IMessageBus.sol";
import "sgn-v2-contracts/contracts/message/libraries/MsgDataTypes.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../BasicXChainAdapter.sol";
import "../agent/IUserAgent.sol";
import "./MessageReceiverApp.sol";
import "./MessageSenderApp.sol";

contract CBridgeXChainAdapter is MessageSenderApp, MessageReceiverApp, BasicXChainAdapter {
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    enum TransferStatus {
        Null,
        Success,
        Refund
    }

    struct TransferEntry {
        address from;
        TransferStatus status;
    }

    struct TransferRequest {
        uint nonce;
        uint toChainId;
        address to;
    }

    struct FallbackEntry {
        uint fromChainId;
        uint nonce;
        address token;
        uint amount;
        uint toChainId;
        address to;
        bool handled;
    }

    uint32 constant MAX_SLIPPAGE = 50000; // 5%

    IERC20Upgradeable public USDC;
    IERC20Upgradeable public USDT;
    uint public nonce;
    // Map of transfer entries (nonce => TransferEntry)
    mapping(uint => TransferEntry) public transfers;
    FallbackEntry[] public fallbacks;

    event Transfer(uint nonce, address from, address indexed token, uint indexed amount, uint indexed toChainId, address to);
    event Receive(uint indexed fromChainId, uint nonce, address indexed token, uint indexed amount, address to);
    event Refund(uint nonce, address from, address indexed token, uint indexed amount, uint indexed toChainId, address to);

    function initialize1(address _messageBus) external initializer {
        super.initialize();
        messageBus = _messageBus;
        USDC = IERC20Upgradeable(Token.getTokenAddress(Const.TokenID.USDC));
        USDT = IERC20Upgradeable(Token.getTokenAddress(Const.TokenID.USDT));
    }

    function transferOwnership(address newOwner) public virtual override(BasicXChainAdapter, OwnableUpgradeable) onlyOwner {
        BasicXChainAdapter.transferOwnership(newOwner);
    }

    // ============== functions on source chain ==============

    // called on source chain for handling of bridge failures (bad liquidity, bad slippage, etc...)
    function executeMessageWithTransferRefund(
        address _token,
        uint256 _amount,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        TransferRequest memory req = abi.decode((_message), (TransferRequest));
        uint _nonce = req.nonce;
        uint _toChainId = req.toChainId;
        address _to = req.to;

        require(transfers[_nonce].status != TransferStatus.Refund, "Already refunded");
        transfers[_nonce].status = TransferStatus.Refund;
        address from = transfers[_nonce].from;

        IERC20Upgradeable(_token).safeTransfer(from, _amount);
        if (from.isContract()) {
            IUserAgent(from).onRefunded(_nonce, _token, _amount, _toChainId, _to);
        }

        emit Refund(_nonce, from, _token, _amount, _toChainId, _to);
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
        require(peers[_srcChainId] == _sender, "Wrong sender");

        (address targetContract, uint targetCallValue, bytes memory targetCallData)
            = abi.decode(_message, (address, uint, bytes));
        (bool success,) = targetContract.call{value: targetCallValue}(targetCallData);
        return (success == true) ? ExecutionStatus.Success : ExecutionStatus.Fail;
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
        require(peers[_srcChainId] == _sender, "Wrong sender");

        TransferRequest memory req = abi.decode((_message), (TransferRequest));
        IERC20Upgradeable(_token).safeTransfer(req.to, _amount);

        emit Receive(_srcChainId, req.nonce, _token, _amount, req.to);
        return ExecutionStatus.Success;
    }

    ///@notice This functions won't be called because executeMessageWithTransfer always returns Success.
    // handler function required by MsgReceiverApp
    // called only if handleMessageWithTransfer above was reverted
    function executeMessageWithTransferFallback(
        address, // _sender
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        TransferRequest memory req = abi.decode((_message), (TransferRequest));
        fallbacks.push(FallbackEntry({
            fromChainId: _srcChainId,
            nonce: req.nonce,
            token: _token,
            amount: _amount,
            toChainId: req.toChainId,
            to: req.to,
            handled: false
        }));
        return ExecutionStatus.Success;
    }

    function transfer(
        Const.TokenID _tokenId,
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        address[] memory _toAddresses
    ) external payable override onlyRole(CLIENT_ROLE) {
        uint count = _amounts.length;
        uint fee = calcTransferFee();
        require(msg.value >= (fee * count), "No enough fee");
        address from = _msgSender();

        uint amount;
        for (uint i = 0; i < count; i++) {
            amount += _amounts[i];
        }

        IERC20Upgradeable token;
        if (_tokenId == Const.TokenID.USDT) {
            token = USDT;
        } else if (_tokenId == Const.TokenID.USDC) {
            token = USDC;
        } else {
            return;
        }
        token.safeTransferFrom(from, address(this), amount);

        for (uint i = 0; i < count; i++) {
            _transfer(from, address(token), _amounts[i], _toChainIds[i], _toAddresses[i], fee);
        }
    }

    function _transfer(
        address _from,
        address _token,
        uint _amount,
        uint _toChainId,
        address _to,
        uint _fee
    ) internal {
        address peer = peers[_toChainId];
        require(peer != address(0), "No peer");
        uint _nonce = nonce;

        transfers[_nonce] = TransferEntry({
            from: _from,
            status: TransferStatus.Null
        });

        bytes memory message = abi.encode(TransferRequest({
            nonce: _nonce,
            toChainId: _toChainId,
            to: _to
        }));

        // MsgSenderApp util function
        sendMessageWithTransfer(
            peer,
            _token,
            _amount,
            uint64(_toChainId),
            uint64(_nonce),
            MAX_SLIPPAGE,
            message,
            MsgDataTypes.BridgeSendType.Liquidity,
            _fee
        );
        nonce ++;
        emit Transfer(_nonce, msg.sender, _token, _amount, _toChainId, _to);
    }

    function call(
        uint _toChainId,
        address _targetContract,
        uint _targetCallValue,
        bytes memory _targetCallData
    ) external payable override onlyRole(CLIENT_ROLE) {
        address peer = peers[_toChainId];
        require(peer != address(0), "No peer");

        bytes memory data = abi.encode(_targetContract, _targetCallValue, _targetCallData);
        sendMessage(peer, uint64(_toChainId), data, msg.value);
    }

    function calcTransferFee() public view override returns (uint) {
        bytes memory message = abi.encode(TransferRequest({
            nonce: nonce,
            toChainId: 0,
            to: address(0)
        }));
        return IMessageBus(messageBus).calcFee(message);
    }

    function calcCallFee(
        uint, // _toChainId
        address _targetContract,
        uint _targetCallValue,
        bytes memory _targetCallData
    ) public view override returns (uint) {
        bytes memory message = abi.encode(_targetContract, _targetCallValue, _targetCallData);
        return IMessageBus(messageBus).calcFee(message);
    }
}
