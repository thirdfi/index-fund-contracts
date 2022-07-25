// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./BasicSTIStrategy.sol";
import "../../bni/constant/BscConstant.sol";
import "../../../interfaces/IStVault.sol";
import "../../../libs/Const.sol";

contract BscSTIStrategy is BasicSTIStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IStVault public BNBVault;

    function initialize1(
        address _admin,
        address _priceOracle,
        IStVault _BNBVault
    ) public initializer {
        super.initialize(
            _admin,
            _priceOracle,
            0x10ED43C718714eb63d5aA57B78B54704E256024E, // PancakeSwap
            BscConstant.WBNB,
            BscConstant.USDT,
            Const.NATIVE_ASSET
        );

        BNBVault = _BNBVault;
    }

    function setStVault(IStVault _BNBVault) external onlyOwner {
        BNBVault = _BNBVault;
    }

    function getStVault(uint _pid) internal view override returns (IStVault stVault) {
        address token = tokens[_pid];
        if (token == Const.NATIVE_ASSET) {
            stVault = BNBVault;
        }
    }

}
