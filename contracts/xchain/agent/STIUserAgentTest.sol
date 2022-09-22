//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../../bni/constant/AuroraConstantTest.sol";
import "../../bni/constant/AvaxConstantTest.sol";
import "../../sti/ISTIMinter.sol";
import "../../sti/ISTIVault.sol";
import "../../swap/ISwap.sol";
import "./STIUserAgent.sol";
import "./BasicUserAgent.sol";

contract STIUserAgentTest is STIUserAgent {

    function initialize1(
        address _subImpl,
        address _treasury,
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

        treasuryWallet = _treasury;
        admin = _admin;
        setSwapper(_swap);
        setMultichainAdapter(_multichainAdapter);
        setCBridgeAdapter(_cbridgeAdapter);

        subImpl = _subImpl;
        chainIdOnLP = AvaxConstantTest.CHAINID;
        isLPChain = (chainIdOnLP == Token.getChainID());
        callAdapterTypes[AuroraConstantTest.CHAINID] = AdapterType.CBridge; // Multichain is not supported on Aurora

        stiMinter = _stiMinter;
        setSTIVault(_stiVault);
    }

    function initDeposit(uint _pool, uint _USDT6Amt, bytes calldata _signature) external payable override whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint leftFee = msg.value;
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _pool, _USDT6Amt)), _signature);

        if (isLPChain) {
            stiMinter.initDepositByAdmin(account, _pool, _USDT6Amt);
        } else {
            // NOTE: cBridge is not supported on Rinkeby 
            _feeAmt = 0;
        }
        nonces[account] = _nonce + 1;
        if (leftFee > 0) Token.safeTransferETH(account, leftFee);
    }

    function temp() public onlyOwner {
        chainIdOnLP = AvaxConstantTest.CHAINID;
        isLPChain = (chainIdOnLP == Token.getChainID());
    }

}
