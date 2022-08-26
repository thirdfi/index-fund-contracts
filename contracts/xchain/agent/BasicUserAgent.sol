//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../libs/BaseRelayRecipient.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../../swap/ISwap.sol";
import "../IXChainAdapter.sol";
import "./BasicUserAgentBase.sol";
import "./IUserAgent.sol";

contract BasicUserAgent is IUserAgent, BasicUserAgentBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    modifier onlyCBridgeAdapter {
        require(msg.sender == address(cbridgeAdapter), "Only cBridge");
        _;
    }

    function initialize(
        address _admin,
        ISwap _swap,
        IXChainAdapter _multichainAdapter, IXChainAdapter _cbridgeAdapter
    ) public virtual initializer {
        __Ownable_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, owner());
        __GnosisSafe_init();

        USDC = IERC20Upgradeable(Token.getTokenAddress(Const.TokenID.USDC));
        USDT = IERC20Upgradeable(Token.getTokenAddress(Const.TokenID.USDT));

        admin = _admin;
        swap = _swap;
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
        USDT.safeApprove(address(multichainAdapter), 0);
        USDC.safeApprove(address(multichainAdapter), 0);
        USDT.safeApprove(address(cbridgeAdapter), 0);
        USDC.safeApprove(address(cbridgeAdapter), 0);
    }

    function unpause() external virtual onlyOwner whenPaused {
        _unpause();
        if (USDT.allowance(address(this), address(multichainAdapter)) == 0) {
            USDT.safeApprove(address(multichainAdapter), type(uint).max);
        }
        if (USDC.allowance(address(this), address(multichainAdapter)) == 0) {
            USDC.safeApprove(address(multichainAdapter), type(uint).max);
        }
        if (USDT.allowance(address(this), address(cbridgeAdapter)) == 0) {
            USDT.safeApprove(address(cbridgeAdapter), type(uint).max);
        }
        if (USDC.allowance(address(this), address(cbridgeAdapter)) == 0) {
            USDC.safeApprove(address(cbridgeAdapter), type(uint).max);
        }
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    function setBiconomy(address _biconomy) external onlyOwner {
        trustedForwarder = _biconomy;
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
        if (oldAdapter == newAdapter) return;

        if (oldAdapter != address(0)) {
            _revokeRole(ADAPTER_ROLE, oldAdapter);
            USDT.safeApprove(oldAdapter, 0);
            USDC.safeApprove(oldAdapter, 0);
        }
        if (newAdapter != address(0)) {
            _setupRole(ADAPTER_ROLE, newAdapter);
            USDC.safeApprove(newAdapter, type(uint).max);
            USDT.safeApprove(newAdapter, type(uint).max);
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

    function setCallAdapterTypes(uint[] memory _chainIds, AdapterType[] memory _adapterTypes) external onlyOwner {
        uint length = _chainIds.length;
        for (uint i = 0; i < length; i++) {
            uint chainId = _chainIds[i];
            require(chainId != 0, "Invalid chainID");
            callAdapterTypes[chainId] = _adapterTypes[i];
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
}
