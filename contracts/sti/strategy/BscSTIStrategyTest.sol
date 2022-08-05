// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./BscSTIStrategy.sol";
import "../../bni/constant/BscConstantTest.sol";
import "../../../interfaces/IStVault.sol";
import "../../../libs/Const.sol";

contract BscSTIStrategyTest is BscSTIStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize1(
        address _admin,
        address _priceOracle,
        IStVault _BNBVault
    ) public override initializer {
        super.initialize(
            _admin,
            _priceOracle,
            0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3, // PancakeSwap
            BscConstantTest.WBNB,
            BscConstantTest.USDT,
            Const.NATIVE_ASSET
        );

        BNBVault = _BNBVault;
    }

}
