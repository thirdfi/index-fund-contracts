// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./AvaxSTIStrategy.sol";
import "../../bni/constant/AvaxConstantTest.sol";
import "../../swap/vendor/IJoeRouter.sol";
import "../../../interfaces/IStVault.sol";
import "../../../libs/Const.sol";

contract AvaxSTIStrategyTest is AvaxSTIStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize1(
        address _admin,
        address _priceOracle,
        IStVault _AVAXVault
    ) public override initializer {
        super.initialize(
            _admin,
            _priceOracle,
            0xd7f655E3376cE2D7A2b08fF01Eb3B1023191A901, // TraderJoe
            AvaxConstantTest.WAVAX,
            AvaxConstantTest.USDT,
            Const.NATIVE_ASSET
        );

        AVAXVault = _AVAXVault;
    }

    function _swapETH(address _tokenB, uint _amt, uint /*_minAmount*/) internal override returns (uint) {
        address[] memory path = new address[](2);
        path[0] = address(SWAP_BASE_TOKEN);
        path[1] = _tokenB;
        return (IJoeRouter(address(router)).swapExactAVAXForTokens{value: _amt}(0, path, address(this), block.timestamp))[1];
    }

    function _swapForETH(address _tokenA, uint _amt, uint /*_minAmount*/) internal override returns (uint) {
        address[] memory path = new address[](2);
        path[0] = _tokenA;
        path[1] = address(SWAP_BASE_TOKEN);
        return (IJoeRouter(address(router)).swapExactTokensForAVAX(_amt, 0, path, address(this), block.timestamp))[1];
    }
}
