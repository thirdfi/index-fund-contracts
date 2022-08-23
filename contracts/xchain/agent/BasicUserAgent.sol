//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../../../libs/multiSig/GnosisSafeUpgradeable.sol";
import "../../../libs/BaseRelayRecipient.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../IXChainAdapter.sol";
import "./IUserAgent.sol";

interface ICBridgeAdapter is IXChainAdapter {
    function nonce() external view returns (uint);
}

contract BasicUserAgent is
    IUserAgent,
    BaseRelayRecipient,
    GnosisSafeUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    enum AdapterType {
        Multichain,
        CBridge
    }

    address public admin;
    mapping(address => uint) public nonces;

    IERC20Upgradeable public USDC;
    mapping(address => uint) public usdcBalances;
    IERC20Upgradeable public USDT;
    mapping(address => uint) public usdtBalances;

    IXChainAdapter public multichainAdapter;

    IXChainAdapter public cbridgeAdapter;
    // Map of transfer addresses (cbridgeAdapter's nonce => sender)
    mapping(uint => address) public cbridgeSenders;

    modifier onlyCBridgeAdapter {
        require(msg.sender == address(cbridgeAdapter), "Only cBridge");
        _;
    }

    function initialize(
        address _admin,
        IXChainAdapter _multichainAdapter, IXChainAdapter _cbridgeAdapter
    ) public virtual initializer {
        __GnosisSafe_init();
        USDC = IERC20Upgradeable(Token.getTokenAddress(Const.TokenID.USDC));
        USDT = IERC20Upgradeable(Token.getTokenAddress(Const.TokenID.USDT));

        admin = _admin;
        setMultichainAdapter(_multichainAdapter);
        setCBridgeAdapter(_cbridgeAdapter);
    }

    function pause() external virtual onlyOwner whenNotPaused {
        _pause();
        USDT.approve(address(multichainAdapter), 0);
        USDC.approve(address(multichainAdapter), 0);
        USDT.approve(address(cbridgeAdapter), 0);
        USDC.approve(address(cbridgeAdapter), 0);
    }

    function unpause() external virtual onlyOwner whenPaused {
        _unpause();
        if (USDT.allowance(address(this), address(multichainAdapter)) == 0) {
            USDT.approve(address(multichainAdapter), type(uint).max);
        }
        if (USDC.allowance(address(this), address(multichainAdapter)) == 0) {
            USDC.approve(address(multichainAdapter), type(uint).max);
        }
        if (USDT.allowance(address(this), address(cbridgeAdapter)) == 0) {
            USDT.approve(address(cbridgeAdapter), type(uint).max);
        }
        if (USDC.allowance(address(this), address(cbridgeAdapter)) == 0) {
            USDC.approve(address(cbridgeAdapter), type(uint).max);
        }
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    function _msgSender() internal override(ContextUpgradeable, BaseRelayRecipient) view returns (address) {
        return BaseRelayRecipient._msgSender();
    }

    function versionRecipient() external pure override returns (string memory) {
        return "1";
    }

    function setMultichainAdapter(IXChainAdapter _multichainAdapter) public onlyOwner {
        onChangeAdapter(address(multichainAdapter), address(_multichainAdapter));
        multichainAdapter = _multichainAdapter;
    }

    function setCBridgeAdapter(IXChainAdapter _cbridgeAdapter) public onlyOwner {
        onChangeAdapter(address(cbridgeAdapter), address(_cbridgeAdapter));
        cbridgeAdapter = _cbridgeAdapter;
    }

    function onChangeAdapter(address oldAdapter, address newAdapter) internal {
        require(oldAdapter != newAdapter, "Same");
        if (oldAdapter != address(0)) {
            USDT.approve(oldAdapter, 0);
            USDC.approve(oldAdapter, 0);
        }
        if (newAdapter != address(0)) {
            USDC.approve(newAdapter, type(uint).max);
            USDT.approve(newAdapter, type(uint).max);
        }
    }

    ///@notice Never revert in this function. If not, cbridgeAdapter.executeMessageWithTransferRefund will be failed.
    function onRefunded(
        uint _cbridgeNonce,
        address _token,
        uint amount,
        uint, // _toChainId
        address // _to
    ) external onlyCBridgeAdapter {
        address sender = cbridgeSenders[_cbridgeNonce];
        if (_token == address(USDT)) usdtBalances[sender] += amount;
        else if (_token == address(USDC)) usdcBalances[sender] += amount;
    }

    function transfer(
        address _from,
        Const.TokenID _tokenId,
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        address[] memory _toAddresses,
        AdapterType[] memory _adapterTypes
    ) internal returns (uint _feeAmt) {
        uint length = _amounts.length;
        uint mchainReqCount;
        uint cbridgeReqCount;
        for (uint i = 0; i < length; i ++) {
            if (_adapterTypes[i] == AdapterType.Multichain) mchainReqCount ++;
            else if (_adapterTypes[i] == AdapterType.CBridge) cbridgeReqCount ++;
        }

        uint[] memory mchainAmounts = new uint[](mchainReqCount);
        uint[] memory mchainToChainIds = new uint[](mchainReqCount);
        address[] memory mchainToAddresses = new address[](mchainReqCount);
        uint[] memory cbridgeAmounts = new uint[](cbridgeReqCount);
        uint[] memory cbridgeToChainIds = new uint[](cbridgeReqCount);
        address[] memory cbridgeToAddresses = new address[](cbridgeReqCount);

        mchainReqCount = 0;
        cbridgeReqCount = 0;
        for (uint i = 0; i < length; i ++) {
            if (_adapterTypes[i] == AdapterType.Multichain) {
                mchainAmounts[mchainReqCount] = _amounts[i];
                mchainToChainIds[mchainReqCount] = _toChainIds[i];
                mchainToAddresses[mchainReqCount] = _toAddresses[i];
                mchainReqCount ++;
            } else if (_adapterTypes[i] == AdapterType.CBridge) {
                cbridgeAmounts[cbridgeReqCount] = _amounts[i];
                cbridgeToChainIds[cbridgeReqCount] = _toChainIds[i];
                cbridgeToAddresses[cbridgeReqCount] = _toAddresses[i];
                cbridgeReqCount ++;
            } else {
                revert("Invalid adapter type");
            }
        }

        if (mchainReqCount > 0) {
            multichainAdapter.transfer(_tokenId, mchainAmounts, mchainToChainIds, mchainToAddresses);
        }
        if (cbridgeReqCount > 0) {
            uint cbridgeNonce = ICBridgeAdapter(address(cbridgeAdapter)).nonce();
            _feeAmt = cbridgeAdapter.calcTransferFee() * cbridgeReqCount;
            cbridgeAdapter.transfer{value: _feeAmt}(_tokenId, cbridgeAmounts, cbridgeToChainIds, cbridgeToAddresses);
            for (uint _nonce = cbridgeNonce; _nonce < (cbridgeNonce + cbridgeReqCount); _nonce ++) {
                cbridgeSenders[_nonce] = _from;
            }
        }
    }

    function call(
        uint _toChainId,
        address _targetContract,
        uint _targetCallValue,
        bytes memory _targetCallData,
        AdapterType _adapterType
    ) internal returns (uint _feeAmt) {
        IXChainAdapter adapter;
        if (_adapterType == AdapterType.Multichain) adapter = multichainAdapter;
        else if (_adapterType == AdapterType.CBridge) adapter = cbridgeAdapter;
        else revert("Invalid adapter type");

        _feeAmt = adapter.calcCallFee(_toChainId, _targetContract, _targetCallValue, _targetCallData);
        adapter.call{value: _feeAmt}(_toChainId, _targetContract, _targetCallValue, _targetCallData);
    }

    receive() external payable {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[41] private __gap;
}
