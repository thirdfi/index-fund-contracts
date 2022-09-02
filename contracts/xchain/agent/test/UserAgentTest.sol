//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../../libs/Const.sol";
import "../../../../libs/Token.sol";
import "../../../bni/constant/AuroraConstantTest.sol";
import "../../../bni/constant/AvaxConstantTest.sol";
import "../../../bni/IBNIMinter.sol";
import "../../../bni/IBNIVault.sol";
import "../../../swap/ISwap.sol";
import "../BasicUserAgent.sol";
import "../BNIUserAgentBase.sol";
import "../../../bni/constant/AuroraConstantTest.sol";
import "../../../bni/constant/AvaxConstantTest.sol";
import "../../../bni/constant/BscConstantTest.sol";
import "../../../bni/constant/EthConstantTest.sol";
import "../../../bni/constant/FtmConstantTest.sol";
import "../../../bni/constant/MaticConstantTest.sol";

contract UserAgentTest is BNIUserAgentBase, BasicUserAgent {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint public testValue;

    event TestCall(uint newTestValue);

    function initialize1(
        address _subImpl,
        address _admin,
        ISwap _swap,
        IXChainAdapter _multichainAdapter, IXChainAdapter _cbridgeAdapter,
        IBNIMinter _bniMinter, IBNIVault _bniVault
    ) external virtual initializer {
        __Ownable_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, owner());
        __GnosisSafe_init();

        USDC = IERC20Upgradeable(Token.getTestTokenAddress(Const.TokenID.USDC));
        USDT = IERC20Upgradeable(getTestTokenAddress());

        admin = _admin;
        swap = _swap;
        setMultichainAdapter(_multichainAdapter);
        setCBridgeAdapter(_cbridgeAdapter);

        subImpl = _subImpl;
        chainIdOnLP = AvaxConstantTest.CHAINID;
        isLPChain = (chainIdOnLP == Token.getChainID());
        callAdapterTypes[AuroraConstantTest.CHAINID] = AdapterType.CBridge; // Multichain is not supported on Aurora

        bniMinter = _bniMinter;
        setBNIVault(_bniVault);
    }

    function getTestTokenAddress() internal view returns (address) {
        uint chainId = Token.getChainID();
        if (chainId == AuroraConstantTest.CHAINID) {
            return AuroraConstantTest.USDT;
        } else if (chainId == AvaxConstantTest.CHAINID) {
            return AvaxConstantTest.USDT;
        } else if (chainId == BscConstantTest.CHAINID) {
            return 0x7d43AABC515C356145049227CeE54B608342c0ad; // It' used in cBridge
        } else if (chainId == EthConstantTest.CHAINID) {
            return EthConstantTest.USDT;
        } else if (chainId == FtmConstantTest.CHAINID) {
            return 0x7d43AABC515C356145049227CeE54B608342c0ad; // It's used in cBridge.
        } else if (chainId == MaticConstantTest.CHAINID) {
            return MaticConstantTest.USDT;
        }
        return address(0);
    }

    function transferOwnership(address newOwner) public virtual override(BasicUserAgent, OwnableUpgradeable) onlyOwner {
        BasicUserAgent.transferOwnership(newOwner);
    }

    function setBNIMinter(IBNIMinter _bniMinter) external onlyOwner {
        bniMinter = _bniMinter;
    }

    function setBNIVault(IBNIVault _bniVault) public onlyOwner {
        address oldVault = address(bniVault);
        if (oldVault != address(0)) {
            USDT.safeApprove(oldVault, 0);
        }

        bniVault = _bniVault;
        if (address(_bniVault) != address(0) && USDT.allowance(address(this), address(_bniVault)) == 0) {
            USDT.safeApprove(address(_bniVault), type(uint).max);
        }
    }

    function testCall(uint _toChainId, uint _value) external payable virtual onlyOwner returns (uint _feeAmt) {
        if (!isLPChain) {
            bytes memory _targetCallData = abi.encodeWithSelector(
                UserAgentTest.testCallByAdmin.selector,
                _value
            );
            _feeAmt = _call(_toChainId, userAgents[_toChainId], 0, _targetCallData, false);
        }
    }

    function testCallByAdmin(uint _value) external onlyRole(ADAPTER_ROLE) {
        testValue = _value;
        emit TestCall(_value);
    }

    /// @dev It calls initDepositByAdmin of BNIMinter.
    /// @param _pool total pool in USD
    /// @param _USDT6Amt USDT with 6 decimals to be deposited
    function initDeposit(uint _pool, uint _USDT6Amt) external payable virtual whenNotPaused onlyOwner returns (uint _feeAmt) {
        address account = _msgSender();

        if (isLPChain) {
            bniMinter.initDepositByAdmin(account, _pool, _USDT6Amt);
        } else {
            bytes memory _targetCallData = abi.encodeWithSelector(
                UserAgentTest.initDepositByAdmin.selector,
                account, _pool, _USDT6Amt
            );
            _feeAmt = _call(chainIdOnLP, userAgents[chainIdOnLP], 0, _targetCallData, false);
        }
    }

    function initDepositByAdmin(address _account, uint _pool, uint _USDT6Amt) external onlyRole(ADAPTER_ROLE) {
        bniMinter.initDepositByAdmin(_account, _pool, _USDT6Amt);
    }

    /// @dev It transfers tokens to user agents
    function transfer(
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        AdapterType[] memory _adapterTypes
    ) external payable virtual whenNotPaused onlyOwner returns (uint _feeAmt) {
        address account = _msgSender();
        (address[] memory toAddresses, uint lengthOut) = transferIn(account, _amounts, _toChainIds, _adapterTypes);
        if (lengthOut > 0) {
            _feeAmt = _transfer(account, address(USDT), _amounts, _toChainIds, toAddresses, _adapterTypes, lengthOut, false);
        }
    }

    function transferIn(
        address account,
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        AdapterType[] memory _adapterTypes
    ) internal returns (address[] memory _toAddresses, uint _lengthOut) {
        uint length = _amounts.length;
        _toAddresses = new address[](length);
        uint chainId = Token.getChainID();
        uint amountOn;
        uint amountOut;
        for (uint i = 0; i < length; i ++) {
            uint amount = _amounts[i];
            uint toChainId = _toChainIds[i];
            if (toChainId == chainId) {
                amountOn += amount;
            } else {
                if (_lengthOut != i) {
                    _amounts[_lengthOut] = amount;
                    _toChainIds[_lengthOut] = toChainId;
                    _adapterTypes[_lengthOut] = _adapterTypes[i];
                }
                address toUserAgent = userAgents[toChainId];
                require(toUserAgent != address(0), "Invalid user agent");
                _toAddresses[_lengthOut] = toUserAgent;

                _lengthOut ++;
                amountOut += amount;
            }
        }

        USDT.safeTransferFrom(account, address(this), amountOn + amountOut);
        usdtBalances[account] += amountOn;
    }

    /// @dev It calls depositByAdmin of BNIVaults.
    function deposit(
        uint[] memory _toChainIds,
        address[] memory _tokens,
        uint[] memory _USDTAmts,
        uint _minterNonce
    ) external payable returns (uint _feeAmt) {
        _toChainIds;
        _tokens;
        _USDTAmts;
        _minterNonce;
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
    function mint(uint _USDT6Amt) external payable returns (uint _feeAmt) {
        _USDT6Amt;
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
    function burn(uint _pool, uint _share) external payable returns (uint _feeAmt) {
        _pool;
        _share;
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
        uint[] memory _chainIds, uint _sharePerc, uint _minterNonce
    ) external payable returns (uint _feeAmt) {
        _chainIds;
        _sharePerc;
        _minterNonce;
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
        AdapterType[] memory _adapterTypes
    ) external payable returns (uint _feeAmt) {
        _fromChainIds;
        _adapterTypes;
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
    function exitWithdrawal(uint _gatheredAmount) external payable returns (uint _feeAmt) {
        _gatheredAmount;
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
    function takeOut(uint _gatheredAmount) external {
        _gatheredAmount;
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
