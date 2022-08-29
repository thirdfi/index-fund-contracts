// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./vendor/IJoeRouter.sol";
import "./BasicSwap.sol";

contract AvaxSwap is BasicSwap {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function swapExactETHForTokens(address _tokenB, uint _minAmount) external payable override returns (uint) {
        address[] memory path = new address[](2);
        path[0] = address(SWAP_BASE_TOKEN);
        path[1] = address(_tokenB);
        return (IJoeRouter(address(router)).swapExactAVAXForTokens{value: msg.value}(_minAmount, path, _msgSender(), block.timestamp))[1];
    }

    function swapTokensForExactETH(address _tokenA, uint _amountInMax, uint _amountOut) external override returns (uint _spentTokenAmount) {
        address account = _msgSender();
        IERC20Upgradeable(_tokenA).safeTransferFrom(account, address(this), _amountInMax);
        IERC20Upgradeable(_tokenA).safeApprove(address(router), _amountInMax);

        address[] memory path = new address[](2);
        path[0] = address(_tokenA);
        path[1] = address(SWAP_BASE_TOKEN);
        _spentTokenAmount = (IJoeRouter(address(router)).swapTokensForExactAVAX(_amountOut, _amountInMax, path, account, block.timestamp))[0];
        if (_amountInMax > _spentTokenAmount) {
            IERC20Upgradeable(_tokenA).safeTransfer(account, _amountInMax - _spentTokenAmount);
        }
    }

    function swapExactTokensForETH(address _tokenA, uint _amt, uint _minAmount) external override returns (uint) {
        address account = _msgSender();
        IERC20Upgradeable(_tokenA).safeTransferFrom(account, address(this), _amt);
        IERC20Upgradeable(_tokenA).safeApprove(address(router), _amt);

        address[] memory path = new address[](2);
        path[0] = address(_tokenA);
        path[1] = address(SWAP_BASE_TOKEN);
        return (IJoeRouter(address(router)).swapExactTokensForAVAX(_amt, _minAmount, path, account, block.timestamp))[1];
    }
}
