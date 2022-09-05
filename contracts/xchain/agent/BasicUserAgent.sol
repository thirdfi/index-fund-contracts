//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "sgn-v2-contracts/contracts/message/interfaces/IMessageReceiverApp.sol";
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
        address _treasury, address _admin,
        ISwap _swap,
        IXChainAdapter _multichainAdapter, IXChainAdapter _cbridgeAdapter
    ) public virtual initializer {
        require(_treasury != address(0), "treasury invalid");

        __Ownable_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, owner());
        __GnosisSafe_init();

        USDC = IERC20Upgradeable(Token.getTokenAddress(Const.TokenID.USDC));
        USDT = IERC20Upgradeable(Token.getTokenAddress(Const.TokenID.USDT));

        treasuryWallet = _treasury;
        admin = _admin;
        setSwapper(_swap);
        setMultichainAdapter(_multichainAdapter);
        setCBridgeAdapter(_cbridgeAdapter);

        gasAmounts[IMessageReceiverApp.executeMessageWithTransferRefund.selector] = 164615; // It's the gas amount of refund transaction on cBridge
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

    function setTreasuryWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0), "wallet invalid");
        treasuryWallet = _wallet;
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

    function setSwapper(ISwap _swap) public onlyOwner {
        onChangeTokenSpender(address(swap), address(_swap));
        swap = _swap;
    }

    function onChangeTokenSpender(address oldSpender, address newSpender) internal {
        if (oldSpender == newSpender) return;

        if (oldSpender != address(0)) {
            USDT.safeApprove(oldSpender, 0);
            USDC.safeApprove(oldSpender, 0);
        }
        if (newSpender != address(0)) {
            USDC.safeApprove(newSpender, type(uint).max);
            USDT.safeApprove(newSpender, type(uint).max);
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

    function setGasAmounts(bytes4[] memory _selectors, uint[] memory _amounts) external onlyOwner {
        for (uint i = 0; i < _selectors.length; i++) {
            bytes4 selector = _selectors[i];
            gasAmounts[selector] = _amounts[i];
        }
    }

    function setGasCosts(uint[] memory _chainIds, uint[] memory _costs) external onlyOwner {
        for (uint i = 0; i < _chainIds.length; i++) {
            uint chainId = _chainIds[i];
            gasCosts[chainId] = _costs[i];
        }
    }

    function withdrawFee() external onlyOwner {
        Token.safeTransferETH(treasuryWallet, address(this).balance);
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
