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
import "../IUserAgent.sol";
import "./MessageReceiverApp.sol";
import "./MessageSenderApp.sol";

contract CBridgeXChainAdapter is MessageSenderApp, MessageReceiverApp, BasicXChainAdapter {
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct TransferEntry {
        address from;
        TransferStatus status;
    }

    enum TransferStatus {
        Null,
        Success,
        Refund
    }

    struct TransferRequest {
        uint nonce;
        address to;
    }

    struct FallbackEntry {
        uint fromChainId;
        uint nonce;
        address token;
        uint amount;
        address to;
        bool handled;
    }

    address public USDC;
    address public USDT;
    uint public nonce;
    // Map of transfer entries (nonce => TransferEntry)
    mapping(uint => TransferEntry) public transfers;
    FallbackEntry[] public fallbacks;

    event Transfer(uint nonce, address from, address token, uint amount, uint toChainId, address to);
    event Receive(uint fromChainId, uint nonce, address token, uint amount, address to);

    function initialize(address _messageBus) public initializer {
        super.initialize();
        messageBus = _messageBus;
        USDC = Token.getTokenAddress(Const.TokenID.USDC);
        USDT = Token.getTokenAddress(Const.TokenID.USDT);
    }

    function transferOwnership(address newOwner) public virtual override(OwnableUpgradeable, BasicXChainAdapter) onlyOwner {
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
        require(transfers[_nonce].status != TransferStatus.Refund, "Already refunded");
        transfers[_nonce].status = TransferStatus.Refund;

        address from = transfers[_nonce].from;
        IERC20Upgradeable(_token).safeTransfer(from, _amount);
        if (from.isContract()) {
            IUserAgent(from).onRefunded(address(this), _token, _amount, _nonce);
        }
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
        TransferRequest memory req = abi.decode((_message), (TransferRequest));
        IERC20Upgradeable(_token).safeTransfer(req.to, _amount);
        emit Receive(_srcChainId, req.nonce, _token, _amount, req.to);
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
        TransferRequest memory req = abi.decode((_message), (TransferRequest));
        fallbacks.push(FallbackEntry({
            fromChainId: _srcChainId,
            nonce: req.nonce,
            token: _token,
            amount: _amount,
            to: req.to,
            handled: false
        }));
        return ExecutionStatus.Success;
    }

    function transfer(
        uint8 _tokenId,
        uint[] memory _amounts,
        address _from,
        uint[] memory _toChainIds,
        address[] memory _toAddresses
    ) external payable override onlyRole(CLIENT_ROLE) {
        uint count = _amounts.length;
        uint fee = calcMessageFee(0, "");
        require(msg.value >= (fee * count), "No enough fee");

        uint amount;
        for (uint i = 0; i < count; i++) {
            amount += _amounts[i];
        }

        address token;
        if (_tokenId == uint8(Const.TokenID.USDT)) {
            token = USDT;
        } else if (_tokenId == uint8(Const.TokenID.USDC)) {
            token = USDC;
        } else {
            revert("unsupported token");
        }
        IERC20Upgradeable(token).safeTransferFrom(_from, address(this), amount);

        for (uint i = 0; i < count; i++) {
            _transfer(token, _amounts[i], _toChainIds[i], _toAddresses[i], fee);
        }
    }

    function _transfer(
        address _token,
        uint _amount,
        uint _toChainId,
        address _to,
        uint _fee
    ) internal {
        address peer = peers[_toChainId];
        require(peer != address(0), "No peer");

        transfers[nonce] = TransferEntry({
            from: msg.sender,
            status: TransferStatus.Null
        });

        bytes memory message = abi.encode(
            TransferRequest({nonce: nonce, to: _to})
        );

        // MsgSenderApp util function
        sendMessageWithTransfer(
            peer,
            _token,
            _amount,
            uint64(_toChainId),
            uint64(nonce),
            50000, // MaxSlippage is 5%
            message,
            MsgDataTypes.BridgeSendType.Liquidity,
            _fee
        );
        nonce ++;
        emit Transfer(nonce, msg.sender, _token, _amount, _toChainId, _to);
    }

    function calcMessageFee(
        uint _toChainId,
        bytes memory _targetCallData
    ) public view override returns (uint) {
        return IMessageBus(messageBus).calcFee(_targetCallData);
    }
}
