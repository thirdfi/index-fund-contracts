//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../../bni/constant/AuroraConstant.sol";
import "../../bni/constant/AvaxConstant.sol";
import "../../bni/IBNIMinter.sol";
import "../../bni/IBNIVault.sol";
import "../../swap/ISwap.sol";
import "./BasicUserAgent.sol";
import "./BNIUserAgentBase.sol";

interface IBNIUserAgentSub {
    function gatherByAdmin(address _account, uint _toChainId, BasicUserAgentBase.AdapterType _adapterType) external;
}

contract BNIUserAgent is BNIUserAgentBase, BasicUserAgent {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize1(
        address _subImpl,
        address _treasury,
        address _admin,
        ISwap _swap,
        IXChainAdapter _multichainAdapter, IXChainAdapter _cbridgeAdapter,
        IBNIMinter _bniMinter, IBNIVault _bniVault
    ) external virtual initializer {
        super.initialize(_treasury, _admin, _swap, _multichainAdapter, _cbridgeAdapter);

        subImpl = _subImpl;
        chainIdOnLP = AvaxConstant.CHAINID;
        isLPChain = (chainIdOnLP == Token.getChainID());
        callAdapterTypes[AuroraConstant.CHAINID] = AdapterType.CBridge; // Multichain is not supported on Aurora

        bniMinter = _bniMinter;
        setBNIVault(_bniVault);

        gasAmounts[IBNIMinter.initDepositByAdmin.selector] = 133213;
        gasAmounts[IBNIMinter.mintByAdmin.selector] = 168205;
        gasAmounts[IBNIMinter.burnByAdmin.selector] = 153743;
        gasAmounts[IBNIMinter.exitWithdrawalByAdmin.selector] = 69845;
        gasAmounts[IBNIVault.depositByAdmin.selector] = 580678;
        gasAmounts[IBNIVault.withdrawPercByAdmin.selector] = 716679;
        gasAmounts[IBNIUserAgentSub.gatherByAdmin.selector] = 437744;
    }

    function transferOwnership(address newOwner) public virtual override(BasicUserAgent, OwnableUpgradeable) onlyOwner {
        BasicUserAgent.transferOwnership(newOwner);
    }

    function setBNIMinter(IBNIMinter _bniMinter) external onlyOwner {
        bniMinter = _bniMinter;
    }

    function setBNIVault(IBNIVault _bniVault) public onlyOwner {
        require(address(_bniVault) != address(0), "Invalid vault");

        address oldVault = address(bniVault);
        if (oldVault != address(0)) {
            USDT.safeApprove(oldVault, 0);
            USDC.safeApprove(oldVault, 0);
        }

        bniVault = _bniVault;
        if (USDT.allowance(address(this), address(_bniVault)) == 0) {
            USDT.safeApprove(address(_bniVault), type(uint).max);
        }
        if (USDC.allowance(address(this), address(_bniVault)) == 0) {
            USDC.safeApprove(address(_bniVault), type(uint).max);
        }
    }

    /// @dev It calls initDepositByAdmin of BNIMinter.
    /// @param _pool total pool in USD
    /// @param _USDT6Amt USDT with 6 decimals to be deposited
    function initDeposit(uint _pool, uint _USDT6Amt, bytes calldata _signature) external payable virtual whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint leftFee = msg.value;
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _pool, _USDT6Amt)), _signature);

        if (isLPChain) {
            bniMinter.initDepositByAdmin(account, _pool, _USDT6Amt);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                BNIUserAgent.initDepositByAdmin.selector,
                account, _pool, _USDT6Amt
            );
            (_feeAmt, leftFee) = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData,
                                        IBNIMinter.initDepositByAdmin.selector, leftFee, false);
        }
        nonces[account] = _nonce + 1;
        if (leftFee > 0) Token.safeTransferETH(account, leftFee);
    }

    function initDepositByAdmin(address _account, uint _pool, uint _USDT6Amt) external onlyRole(ADAPTER_ROLE) {
        bniMinter.initDepositByAdmin(_account, _pool, _USDT6Amt);
    }

    /// @dev It transfers tokens to user agents
    function transfer(
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        AdapterType[] memory _adapterTypes,
        bytes calldata _signature
    ) external payable returns (uint _feeAmt) {
        _amounts;
        _toChainIds;
        _adapterTypes;
        _signature;
        _feeAmt;
        delegateAndReturn();
    }

    /// @dev It calls depositByAdmin of BNIVaults.
    function deposit(
        uint[] memory _toChainIds,
        address[] memory _tokens,
        uint[] memory _USDTAmts,
        uint _minterNonce,
        bytes calldata _signature
    ) external payable returns (uint _feeAmt) {
        _toChainIds;
        _tokens;
        _USDTAmts;
        _minterNonce;
        _signature;
        _feeAmt;
        delegateAndReturn();
    }

    function depositByAgent(
        address _account,
        address[] memory _tokens,
        uint[] memory _USDTAmts,
        uint _minterNonce
    ) external {
        _account;
        _tokens;
        _USDTAmts;
        _minterNonce;
        delegateAndReturn();
    }

    /// @dev It calls mintByAdmin of BNIMinter.
    function mint(uint _USDT6Amt, bytes calldata _signature) external payable returns (uint _feeAmt) {
        _USDT6Amt;
        _signature;
        _feeAmt;
        delegateAndReturn();
    }

    function mintByAdmin(address _account, uint _USDT6Amt) external {
        _account;
        _USDT6Amt;
        delegateAndReturn();
    }

    /// @dev It calls burnByAdmin of BNIMinter.
    /// @param _pool total pool in USD
    /// @param _share amount of shares
    function burn(uint _pool, uint _share, bytes calldata _signature) external payable returns (uint _feeAmt) {
        _pool;
        _share;
        _signature;
        _feeAmt;
        delegateAndReturn();
    }

    function burnByAdmin(address _account, uint _pool, uint _share) external {
        _account;
        _pool;
        _share;
        delegateAndReturn();
    }

    /// @dev It calls withdrawPercByAdmin of BNIVaults.
    function withdraw(
        uint[] memory _chainIds, uint _sharePerc, uint _minterNonce, bytes calldata _signature
    ) external payable returns (uint _feeAmt) {
        _chainIds;
        _sharePerc;
        _minterNonce;
        _signature;
        _feeAmt;
        delegateAndReturn();
    }

    function withdrawPercByAgent(
        address _account, uint _sharePerc, uint _minterNonce
    ) external {
        _account;
        _sharePerc;
        _minterNonce;
        delegateAndReturn();
    }

    /// @dev It gathers withdrawn tokens of the user from user agents.
    function gather(
        uint[] memory _fromChainIds,
        AdapterType[] memory _adapterTypes,
        bytes calldata _signature
    ) external payable returns (uint _feeAmt) {
        _fromChainIds;
        _adapterTypes;
        _signature;
        _feeAmt;
        delegateAndReturn();
    }

    function gatherByAdmin(
        address _account, uint _toChainId, AdapterType _adapterType
    ) external {
        _account;
        _toChainId;
        _adapterType;
        delegateAndReturn();
    }

    /// @dev It calls exitWithdrawalByAdmin of BNIMinter.
    /// @param _gatheredAmount is the amount of token that is gathered.
    /// @notice _gatheredAmount doesn't include the balance which is withdrawan in this agent.
    function exitWithdrawal(uint _gatheredAmount, bytes calldata _signature) external payable returns (uint _feeAmt) {
        _gatheredAmount;
        _signature;
        _feeAmt;
        delegateAndReturn();
    }

    function exitWithdrawalByAdmin(address _account) external {
        _account;
        delegateAndReturn();
    }

    /// @dev It takes out tokens from this agent.
    /// @param _gatheredAmount is the amount of token that is gathered.
    /// @notice _gatheredAmount doesn't include the balance which is withdrawan in this agent.
    function takeOut(uint _gatheredAmount, bytes calldata _signature) external {
        _gatheredAmount;
        _signature;
        delegateAndReturn();
    }

    /**
     * @dev Delegate to sub contract
     */
    function setSubImpl(address _subImpl) external onlyOwner {
        require(_subImpl != address(0), "Invalid address");
        subImpl = _subImpl;
    }

    function delegateAndReturn() private returns (bytes memory) {
        (bool success, ) = subImpl.delegatecall(msg.data);

        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize())

            switch success
            case 0 { revert(free_mem_ptr, returndatasize()) }
            default { return(free_mem_ptr, returndatasize()) }
        }
    }

}
