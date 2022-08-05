// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./BasicSTIStrategyTest.sol";
import "../../bni/constant/AuroraConstantTest.sol";
import "../../../interfaces/IStVault.sol";
import "../../../libs/Const.sol";

contract AuroraSTIStrategyTest is BasicSTIStrategyTest {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IStVault public WNEARVault;

    function initialize1(
        address _admin,
        address _priceOracle,
        IStVault _WNEARVault
    ) public initializer {
        super.initialize(
            _admin,
            _priceOracle,
            0x2CB45Edb4517d5947aFdE3BEAbF95A582506858B, // Trisolaris
            AuroraConstantTest.WNEAR,
            AuroraConstantTest.USDT,
            AuroraConstantTest.WNEAR
        );

        WNEARVault = _WNEARVault;

        // IERC20Upgradeable(AuroraConstantTest.WNEAR).safeApprove(address(WNEARVault), type(uint).max);
    }

    function setStVault(IStVault _WNEARVault) external onlyOwner {
        WNEARVault = _WNEARVault;

        // if (IERC20Upgradeable(AuroraConstantTest.WNEAR).allowance(address(this), address(WNEARVault)) == 0) {
        //     IERC20Upgradeable(AuroraConstantTest.WNEAR).safeApprove(address(WNEARVault), type(uint).max);
        // }
    }

    function getStVault(address _token) internal view override returns (IStVault stVault) {
        if (_token == AuroraConstantTest.WNEAR) {
            stVault = WNEARVault;
        }
    }

}
