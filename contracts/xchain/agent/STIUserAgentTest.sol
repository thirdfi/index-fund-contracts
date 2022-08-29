//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../../bni/constant/EthConstantTest.sol";
import "../../sti/ISTIMinter.sol";
import "../../sti/ISTIVault.sol";
import "../../swap/ISwap.sol";
import "./STIUserAgent.sol";
import "./BasicUserAgent.sol";

contract STIUserAgentTest is STIUserAgent {

    function initialize1(
        address _subImpl,
        address _admin,
        ISwap _swap,
        IXChainAdapter _multichainAdapter, IXChainAdapter _cbridgeAdapter,
        ISTIMinter _stiMinter, ISTIVault _stiVault
    ) external override initializer {
        __Ownable_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, owner());
        __GnosisSafe_init();

        USDC = IERC20Upgradeable(Token.getTestTokenAddress(Const.TokenID.USDC));
        USDT = IERC20Upgradeable(Token.getTestTokenAddress(Const.TokenID.USDT));

        admin = _admin;
        swap = _swap;
        setMultichainAdapter(_multichainAdapter);
        setCBridgeAdapter(_cbridgeAdapter);

        subImpl = _subImpl;
        uint chainId = Token.getChainID();
        chainIdOnLP = EthConstantTest.CHAINID;
        isLPChain = (chainIdOnLP == chainId);

        stiMinter = _stiMinter;
        _setSTIVault(chainId, _stiVault);
    }

    function initDeposit(uint _pool, uint _USDT6Amt, bytes calldata _signature) external payable override whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _pool, _USDT6Amt)), _signature);

        if (isLPChain) {
            stiMinter.initDepositByAdmin(account, _pool, _USDT6Amt);
        } else {
            // NOTE: cBridge is not supported on Rinkeby 
            _feeAmt = 0;
        }
        nonces[account] = _nonce + 1;
    }

    function transfer(
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        AdapterType[] memory _adapterTypes,
        bytes calldata _signature
    ) external payable override whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _amounts, _toChainIds, _adapterTypes)), _signature);

        transferIn(account, _amounts, _toChainIds, _adapterTypes);
        // NOTE: cBridge doesn't support liquidity on testnets
        _feeAmt = 0;
        nonces[account] = _nonce + 1;
    }

}
