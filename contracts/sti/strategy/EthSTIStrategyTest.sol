// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./BasicSTIStrategyTest.sol";
import "../../bni/constant/EthConstantTest.sol";
import "../../../interfaces/IStVault.sol";
import "../../../libs/Const.sol";

contract EthSTIStrategyTest is BasicSTIStrategyTest {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IStVault public ETHVault;
    IStVault public MATICVault;

    function initialize1(
        address _admin,
        address _priceOracle,
        IStVault _ETHVault, IStVault _MATICVault
    ) public initializer {
        super.initialize(
            _admin,
            _priceOracle,
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, // Uniswap2
            EthConstantTest.WETH,
            EthConstantTest.USDT,
            Const.NATIVE_ASSET
        );

        tokens.push(EthConstantTest.MATIC);
        updatePid();

        ETHVault = _ETHVault;
        MATICVault = _MATICVault;

        // IERC20Upgradeable(EthConstantTest.MATIC).safeApprove(address(MATICVault), type(uint).max);
        // IERC20Upgradeable(EthConstantTest.MATIC).safeApprove(address(router), type(uint).max);
    }

    function setStVault(IStVault _ETHVault, IStVault _MATICVault) external onlyOwner {
        ETHVault = _ETHVault;
        MATICVault = _MATICVault;

        // if (IERC20Upgradeable(EthConstantTest.MATIC).allowance(address(this), address(MATICVault)) == 0) {
        //     IERC20Upgradeable(EthConstantTest.MATIC).safeApprove(address(MATICVault), type(uint).max);
        // }
    }

    function getStVault(address _token) internal view override returns (IStVault stVault) {
        if (_token == Const.NATIVE_ASSET) {
            stVault = ETHVault;
        } else if (_token == EthConstantTest.MATIC) {
            stVault = MATICVault;
        }
    }

}
