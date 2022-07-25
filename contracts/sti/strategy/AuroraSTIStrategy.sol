// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./BasicSTIStrategy.sol";
import "../../bni/constant/AuroraConstant.sol";
import "../../../interfaces/IStVault.sol";
import "../../../libs/Const.sol";

contract AuroraSTIStrategy is BasicSTIStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IStVault public WNEARVault;

    function initialize1(
        address _treasury, address _admin,
        address _priceOracle,
        IStVault _WNEARVault
    ) public initializer {
        super.initialize(
            _treasury, _admin,
            _priceOracle,
            0x2CB45Edb4517d5947aFdE3BEAbF95A582506858B, // Trisolaris
            AuroraConstant.WNEAR,
            AuroraConstant.USDT,
            AuroraConstant.WNEAR
        );

        WNEARVault = _WNEARVault;

        IERC20Upgradeable(AuroraConstant.WNEAR).safeApprove(address(WNEARVault), type(uint).max);
    }

    function setStVault(IStVault _WNEARVault) external onlyOwner {
        WNEARVault = _WNEARVault;

        if (IERC20Upgradeable(AuroraConstant.WNEAR).allowance(address(this), address(WNEARVault)) == 0) {
            IERC20Upgradeable(AuroraConstant.WNEAR).safeApprove(address(WNEARVault), type(uint).max);
        }
    }

    function getStVault(uint _pid) internal view override returns (IStVault stVault) {
        address token = tokens[_pid];
        if (token == AuroraConstant.WNEAR) {
            stVault = WNEARVault;
        }
    }

}
