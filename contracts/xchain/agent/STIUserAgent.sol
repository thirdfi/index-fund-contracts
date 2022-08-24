//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../../bni/constant/AvaxConstant.sol";
import "../../sti/ISTIMinter.sol";
import "../../sti/ISTIVault.sol";
import "./BasicUserAgent.sol";

contract STIUserAgent is BasicUserAgent {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    ISTIMinter public stiMinter;

    function initialize1(
        address _admin,
        IXChainAdapter _multichainAdapter, IXChainAdapter _cbridgeAdapter,
        ISTIMinter _stiMinter
    ) external initializer {
        super.initialize(_admin, _multichainAdapter, _cbridgeAdapter);
        stiMinter = _stiMinter;
    }

    function setSTIMinter(ISTIMinter _stiMinter) external onlyOwner {
        stiMinter = _stiMinter;
    }

    /// @param _USDTAmt USDT with 6 decimals to be deposited
    function initDeposit(uint _USDTAmt, bytes calldata _signature) external payable whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint _nonce = nonces[account];
        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(account, _USDTAmt, _nonce)));
        require(isValidSignature(admin, data, _signature), "Invalid signature");

        uint chainId = Token.getChainID();
        if (chainId == AvaxConstant.CHAINID) {
            stiMinter.initDepositByAdmin(account, _USDTAmt);
        } else {
            address _toUserAgent = userAgents[AvaxConstant.CHAINID];
            require(_toUserAgent != address(0), "Invalid Avalanche User Agent");
            bytes memory _targetCallData = abi.encodeWithSelector(STIUserAgent.initDepositByAdmin.selector, account, _USDTAmt);
            _feeAmt = call(AvaxConstant.CHAINID, _toUserAgent, 0, _targetCallData, AdapterType.Multichain);
        }
        nonces[account] = _nonce + 1;
    }

    function initDepositByAdmin(address _account, uint _USDTAmt) external onlyRole(ADAPTER_ROLE) {
        stiMinter.initDepositByAdmin(_account, _USDTAmt);
    }
}
