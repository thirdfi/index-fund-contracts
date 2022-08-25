// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../interfaces/IUniRouter.sol";

contract BasicSwap is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IUniRouter public router;
    IERC20Upgradeable public SWAP_BASE_TOKEN; // It has same role with WETH on Ethereum Swaps. Most of tokens have been paired with this token.

    function initialize(
        IUniRouter _router, IERC20Upgradeable _SWAP_BASE_TOKEN
    ) public virtual initializer {
        require(address(_router) != address(0), "Invalid router");
        require(address(_SWAP_BASE_TOKEN) != address(0), "Invalid SWAP_BASE_TOKEN");
        __Ownable_init();

        router = _router;
        SWAP_BASE_TOKEN = _SWAP_BASE_TOKEN;
    }

    function setRouter(IUniRouter _router) external onlyOwner {
        router = _router;
    }

    function swapExactTokensForTokens(address _tokenA, address _tokenB, uint _amt, uint _minAmount) external virtual returns (uint) {
        address account = _msgSender();
        IERC20Upgradeable(_tokenA).safeTransferFrom(account, address(this), _amt);
        IERC20Upgradeable(_tokenA).safeApprove(address(router), _amt);

        address[] memory path = new address[](2);
        path[0] = _tokenA;
        path[1] = _tokenB;
        return (router.swapExactTokensForTokens(_amt, _minAmount, path, account, block.timestamp))[1];
    }

    function swapExactTokensForTokens2(address _tokenA, address _tokenB, uint _amt, uint _minAmount) external virtual returns (uint) {
        address account = _msgSender();
        IERC20Upgradeable(_tokenA).safeTransferFrom(account, address(this), _amt);
        IERC20Upgradeable(_tokenA).safeApprove(address(router), _amt);

        address[] memory path = new address[](3);
        path[0] = _tokenA;
        path[1] = address(SWAP_BASE_TOKEN);
        path[2] = _tokenB;
        return (router.swapExactTokensForTokens(_amt, _minAmount, path, account, block.timestamp))[2];
    }

    function swapExactETHForTokens(address _tokenB, uint _minAmount) external payable virtual returns (uint) {
        address[] memory path = new address[](2);
        path[0] = address(SWAP_BASE_TOKEN);
        path[1] = _tokenB;
        return (router.swapExactETHForTokens{value: msg.value}(_minAmount, path, _msgSender(), block.timestamp))[1];
    }

    function swapTokensForExactETH(address _tokenA, uint _amountInMax, uint _amountOut) external virtual returns (uint _spentTokenAmount) {
        address account = _msgSender();
        IERC20Upgradeable(_tokenA).safeTransferFrom(account, address(this), _amountInMax);
        IERC20Upgradeable(_tokenA).safeApprove(address(router), _amountInMax);

        address[] memory path = new address[](2);
        path[0] = _tokenA;
        path[1] = address(SWAP_BASE_TOKEN);
        _spentTokenAmount = (router.swapTokensForExactETH(_amountOut, _amountInMax, path, account, block.timestamp))[0];
        if (_amountInMax > _spentTokenAmount) {
            IERC20Upgradeable(_tokenA).safeTransfer(account, _amountInMax - _spentTokenAmount);
        }
    }

    function swapExactTokensForETH(address _tokenA, uint _amt, uint _minAmount) external virtual returns (uint) {
        address account = _msgSender();
        IERC20Upgradeable(_tokenA).safeTransferFrom(account, address(this), _amt);
        IERC20Upgradeable(_tokenA).safeApprove(address(router), _amt);

        address[] memory path = new address[](2);
        path[0] = _tokenA;
        path[1] = address(SWAP_BASE_TOKEN);
        return (router.swapExactTokensForETH(_amt, _minAmount, path, account, block.timestamp))[1];
    }

    function getAmountsInForETH(address _tokenA, uint _amountOut) external view virtual returns (uint) {
        address[] memory path = new address[](2);
        path[0] = _tokenA;
        path[1] = address(SWAP_BASE_TOKEN);
        return (router.getAmountsIn(_amountOut, path))[0];
    }

    receive() external payable {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}
