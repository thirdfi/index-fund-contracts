// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./BasicSTIStrategy.sol";
import "../../bni/constant/MoonbeamConstant.sol";
import "../../../interfaces/IStVault.sol";
import "../../../libs/Const.sol";

contract MoonbeamSTIStrategy is BasicSTIStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IStVault public DOTVault;

    function initialize1(
        address _admin,
        address _priceOracle,
        IStVault _DOTVault
    ) public initializer {
        super.initialize(
            _admin,
            _priceOracle,
            0x70085a09D30D6f8C4ecF6eE10120d1847383BB57, // StellaSwap
            MoonbeamConstant.WGLMR,
            MoonbeamConstant.USDT_mad,
            MoonbeamConstant.xcDOT
        );

        DOTVault = _DOTVault;

        IERC20Upgradeable(MoonbeamConstant.xcDOT).safeApprove(address(DOTVault), type(uint).max);
    }

    function setStVault(IStVault _DOTVault) external onlyOwner {
        DOTVault = _DOTVault;

        if (IERC20Upgradeable(MoonbeamConstant.xcDOT).allowance(address(this), address(DOTVault)) == 0) {
            IERC20Upgradeable(MoonbeamConstant.xcDOT).safeApprove(address(DOTVault), type(uint).max);
        }
    }

    function getStVault(uint _pid) internal view override returns (IStVault stVault) {
        address token = tokens[_pid];
        if (token == MoonbeamConstant.xcDOT) {
            stVault = DOTVault;
        }
    }

}
