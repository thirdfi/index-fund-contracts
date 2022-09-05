//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../../bni/constant/AuroraConstantTest.sol";
import "../../bni/constant/AvaxConstantTest.sol";
import "../../bni/IBNIMinter.sol";
import "../../bni/IBNIVault.sol";
import "../../swap/ISwap.sol";
import "./BNIUserAgent.sol";
import "./BasicUserAgent.sol";

contract BNIUserAgentTest is BNIUserAgent {

    function initialize1(
        address _subImpl,
        address _treasury,
        address _admin,
        ISwap _swap,
        IXChainAdapter _multichainAdapter, IXChainAdapter _cbridgeAdapter,
        IBNIMinter _bniMinter, IBNIVault _bniVault
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

        bniMinter = _bniMinter;
        setBNIVault(_bniVault);
    }
}
