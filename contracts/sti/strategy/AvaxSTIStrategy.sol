// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./BasicSTIStrategy.sol";
import "../../bni/constant/AvaxConstant.sol";
import "../../../interfaces/IStVault.sol";
import "../../../libs/Const.sol";

interface IJoeRouter {
    function swapExactAVAXForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapExactTokensForAVAX(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract AvaxSTIStrategy is BasicSTIStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IStVault public AVAXVault;

    function initialize1(
        address _admin,
        address _priceOracle,
        IStVault _AVAXVault
    ) public virtual initializer {
        super.initialize(
            _admin,
            _priceOracle,
            0x60aE616a2155Ee3d9A68541Ba4544862310933d4, // TraderJoe
            AvaxConstant.WAVAX,
            AvaxConstant.USDT,
            Const.NATIVE_ASSET
        );

        AVAXVault = _AVAXVault;
    }

    function setStVault(IStVault _AVAXVault) external onlyOwner {
        AVAXVault = _AVAXVault;
    }

    function getStVault(address _token) internal view override returns (IStVault stVault) {
        if (_token == Const.NATIVE_ASSET) {
            stVault = AVAXVault;
        }
    }

    function _swapETH(address _tokenB, uint _amt, uint _minAmount) internal override returns (uint) {
        address[] memory path = new address[](2);
        path[0] = address(SWAP_BASE_TOKEN);
        path[1] = _tokenB;
        return (IJoeRouter(address(router)).swapExactAVAXForTokens{value: _amt}(_minAmount, path, address(this), block.timestamp))[1];
    }

    function _swapForETH(address _tokenA, uint _amt, uint _minAmount) internal override returns (uint) {
        address[] memory path = new address[](2);
        path[0] = _tokenA;
        path[1] = address(SWAP_BASE_TOKEN);
        return (IJoeRouter(address(router)).swapExactTokensForAVAX(_amt, _minAmount, path, address(this), block.timestamp))[1];
    }
}
