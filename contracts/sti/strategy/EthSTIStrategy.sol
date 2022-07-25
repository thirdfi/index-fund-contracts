// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./BasicSTIStrategy.sol";
import "../../bni/constant/EthConstant.sol";
import "../../../interfaces/IStVault.sol";
import "../../../libs/Const.sol";

contract EthSTIStrategy is BasicSTIStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IStVault public ETHVault;
    IStVault public MATICVault;

    function initialize1(
        address _treasury, address _admin,
        address _priceOracle,
        IStVault _ETHVault, IStVault _MATICVault
    ) public initializer {
        super.initialize(
            _treasury, _admin,
            _priceOracle,
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, // Uniswap2
            EthConstant.WETH,
            EthConstant.USDT,
            Const.NATIVE_ASSET
        );

        tokens.push(EthConstant.MATIC);
        updatePid();

        ETHVault = _ETHVault;
        MATICVault = _MATICVault;

        IERC20Upgradeable(EthConstant.MATIC).safeApprove(address(MATICVault), type(uint).max);
    }

    function setStVault(IStVault _ETHVault, IStVault _MATICVault) external onlyOwner {
        ETHVault = _ETHVault;
        MATICVault = _MATICVault;

        if (IERC20Upgradeable(EthConstant.MATIC).allowance(address(this), address(MATICVault)) == 0) {
            IERC20Upgradeable(EthConstant.MATIC).safeApprove(address(MATICVault), type(uint).max);
        }
    }

    function getStVault(uint _pid) internal view override returns (IStVault stVault) {
        address token = tokens[_pid];
        if (token == Const.NATIVE_ASSET) {
            stVault = ETHVault;
        } else if (token == EthConstant.MATIC) {
            stVault = MATICVault;
        }
    }

}
