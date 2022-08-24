//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
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
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    enum AdapterType {
        Multichain,
        CBridge
    }

    bytes32 public constant ADAPTER_ROLE = keccak256("ADAPTER_ROLE");

    address public admin;
    mapping(address => uint) public nonces;

    IERC20Upgradeable public USDC;
    IERC20Upgradeable public USDT;
    // These stores the balance that is deposited directly, not cross-transferred.
    // And these also store the refunded amount.
    mapping(address => uint) public usdcBalances;
    mapping(address => uint) public usdtBalances;

    IXChainAdapter public multichainAdapter;
    IXChainAdapter public cbridgeAdapter;
    // Map of transfer addresses (cbridgeAdapter's nonce => sender)
    mapping(uint => address) public cbridgeSenders;

    // Map of user agents (chainId => userAgent).
    mapping(uint => address) public userAgents;

    modifier onlyCBridgeAdapter {
        require(msg.sender == address(cbridgeAdapter), "Only cBridge");
        _;
    }

    function initialize(
        address _admin,
        IXChainAdapter _multichainAdapter, IXChainAdapter _cbridgeAdapter
    ) public virtual initializer {
        __Ownable_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, owner());
        __GnosisSafe_init();

        USDC = IERC20Upgradeable(Token.getTokenAddress(Const.TokenID.USDC));
        USDT = IERC20Upgradeable(Token.getTokenAddress(Const.TokenID.USDT));

        admin = _admin;
        setMultichainAdapter(_multichainAdapter);
        setCBridgeAdapter(_cbridgeAdapter);
    }

    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _revokeRole(DEFAULT_ADMIN_ROLE, owner());
        super.transferOwnership(newOwner);
        _setupRole(DEFAULT_ADMIN_ROLE, newOwner);
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
            _revokeRole(ADAPTER_ROLE, oldAdapter);
            USDT.approve(oldAdapter, 0);
            USDC.approve(oldAdapter, 0);
        }
        if (newAdapter != address(0)) {
            _setupRole(ADAPTER_ROLE, newAdapter);
            USDC.approve(newAdapter, type(uint).max);
            USDT.approve(newAdapter, type(uint).max);
        }
    }

    function setUserAgents(uint[] memory _chainIds, address[] memory _userAgents) external onlyOwner {
        uint length = _chainIds.length;
        for (uint i = 0; i < length; i++) {
            uint chainId = _chainIds[i];
            require(chainId != 0, "Invalid chainID");
            userAgents[chainId] = _userAgents[i];
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
        AdapterType[] memory _adapterTypes,
        uint length
    ) internal returns (uint _feeAmt) {
        (uint[] memory mchainAmounts, uint[] memory mchainToChainIds, address[] memory mchainToAddresses,
        uint[] memory cbridgeAmounts, uint[] memory cbridgeToChainIds, address[] memory cbridgeToAddresses)
            = splitTranfersPerAdapter(_amounts, _toChainIds, _toAddresses, _adapterTypes, length);

        if (mchainAmounts.length > 0) {
            multichainAdapter.transfer(_tokenId, mchainAmounts, mchainToChainIds, mchainToAddresses);
        }
        if (cbridgeAmounts.length > 0) {
            _feeAmt = transferThroughCBridge(_from, _tokenId, cbridgeAmounts, cbridgeToChainIds, cbridgeToAddresses);
        }
    }

    function transferThroughCBridge (
        address _from,
        Const.TokenID _tokenId,
        uint[] memory _cbridgeAmounts,
        uint[] memory _cbridgeToChainIds,
        address[] memory _cbridgeToAddresses
    ) private returns (uint _feeAmt) {
        uint cbridgeReqCount = _cbridgeAmounts.length;
        _feeAmt = cbridgeAdapter.calcTransferFee() * cbridgeReqCount;

        if (address(this).balance >= _feeAmt) {
            uint cbridgeNonce = ICBridgeAdapter(address(cbridgeAdapter)).nonce();
            cbridgeAdapter.transfer{value: _feeAmt}(_tokenId, _cbridgeAmounts, _cbridgeToChainIds, _cbridgeToAddresses);
            for (uint _nonce = cbridgeNonce; _nonce < (cbridgeNonce + cbridgeReqCount); _nonce ++) {
                cbridgeSenders[_nonce] = _from;
            }
        }
    }

    function splitTranfersPerAdapter (
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        address[] memory _toAddresses,
        AdapterType[] memory _adapterTypes,
        uint length
    ) private view returns (
        uint[] memory _mchainAmounts,
        uint[] memory _mchainToChainIds,
        address[] memory _mchainToAddresses,
        uint[] memory _cbridgeAmounts,
        uint[] memory _cbridgeToChainIds,
        address[] memory _cbridgeToAddresses
    ){
        uint mchainReqCount;
        uint cbridgeReqCount;
        for (uint i = 0; i < length; i ++) {
            if (_adapterTypes[i] == AdapterType.Multichain) mchainReqCount ++;
            else if (_adapterTypes[i] == AdapterType.CBridge) cbridgeReqCount ++;
        }

        _mchainAmounts = new uint[](mchainReqCount);
        _mchainToChainIds = new uint[](mchainReqCount);
        _mchainToAddresses = new address[](mchainReqCount);
        _cbridgeAmounts = new uint[](cbridgeReqCount);
        _cbridgeToChainIds = new uint[](cbridgeReqCount);
        _cbridgeToAddresses = new address[](cbridgeReqCount);

        mchainReqCount = 0;
        cbridgeReqCount = 0;
        for (uint i = 0; i < length; i ++) {
            if (_adapterTypes[i] == AdapterType.Multichain) {
                _mchainAmounts[mchainReqCount] = _amounts[i];
                _mchainToChainIds[mchainReqCount] = _toChainIds[i];
                _mchainToAddresses[mchainReqCount] = _toAddresses[i];
                mchainReqCount ++;
            } else if (_adapterTypes[i] == AdapterType.CBridge) {
                _cbridgeAmounts[cbridgeReqCount] = _amounts[i];
                _cbridgeToChainIds[cbridgeReqCount] = _toChainIds[i];
                _cbridgeToAddresses[cbridgeReqCount] = _toAddresses[i];
                cbridgeReqCount ++;
            } else {
                revert("Invalid adapter type");
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
        if (address(this).balance >= _feeAmt) {
            adapter.call{value: _feeAmt}(_toChainId, _targetContract, _targetCallValue, _targetCallData);
        }
    }

    receive() external payable {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[40] private __gap;
}
