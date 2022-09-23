//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../interfaces/IERC20UpgradeableExt.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../../bni/IBNIMinter.sol";
import "../../bni/IBNIVault.sol";
import "./BNIUserAgentSub.sol";

contract BNIUserAgentSubTest is BNIUserAgentSub {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function transfer(
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        AdapterType[] memory _adapterTypes,
        bytes calldata _signature
    ) external payable override whenNotPaused returns (uint _feeAmt) {
        address account = _msgSender();
        uint leftFee = msg.value;
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _amounts, _toChainIds, _adapterTypes)), _signature);

        // NOTE: cBridge doesn't support liquidity on testnets
        uint amountAll;
        for (uint i = 0; i < _amounts.length; i ++) {
            amountAll += _amounts[i];
        }
        USDT.safeTransferFrom(account, address(this), amountAll);
        usdtBalances[account] += amountAll;

        _feeAmt = 0;
        nonces[account] = _nonce + 1;
        if (leftFee > 0) Token.safeTransferETH(account, leftFee);
    }

    function _deposit(
        address _account,
        DepositPerChain memory _depositPerChain,
        uint _minterNonce,
        uint _suppliedFee
    ) internal override returns (uint _feeAmt, uint _leftFee) {
        if (_depositPerChain.toChainId == Token.getChainID()) {
            (_feeAmt, _leftFee) = super._deposit(_account, _depositPerChain, _minterNonce, _suppliedFee);
        } else {
            // NOTE: cBridge doesn't support liquidity on testnets
            _feeAmt = 0;
            _leftFee = _suppliedFee;
        }
    }

    function _withdraw(
        address _account,
        uint _chainId,
        uint _sharePerc,
        uint _minterNonce,
        uint _suppliedFee
    ) internal override returns (uint _feeAmt, uint _leftFee) {
        _leftFee = _suppliedFee;
        if (_chainId == Token.getChainID()) {
            _withdrawFromVault(bniVault, _account, _sharePerc, _minterNonce);
        } else {
            // NOTE: cBridge doesn't support liquidity on testnets
            _feeAmt = 0;
        }
    }

    function gather(
        uint[] memory _fromChainIds,
        AdapterType[] memory _adapterTypes,
        bytes calldata _signature
    ) external payable override returns (uint _feeAmt) {
        address account = _msgSender();
        uint leftFee = msg.value;
        uint _nonce = nonces[account];
        checkSignature(keccak256(abi.encodePacked(account, _nonce, _fromChainIds, _adapterTypes)), _signature);

        // NOTE: cBridge doesn't support liquidity on testnets
        _feeAmt = 0;
        nonces[account] = _nonce + 1;
        if (leftFee > 0) Token.safeTransferETH(account, leftFee);
    }

}
