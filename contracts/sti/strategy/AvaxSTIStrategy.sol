// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./BasicSTIStrategy.sol";
import "../../bni/constant/AvaxConstant.sol";
import "../../../interfaces/IStVault.sol";
import "../../../libs/Const.sol";

contract AvaxSTIStrategy is BasicSTIStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IStVault public AVAXVault;

    function initialize1(
        address _treasury, address _admin,
        address _priceOracle,
        IStVault _AVAXVault
    ) public initializer {
        super.initialize(
            _treasury, _admin,
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

    function getStVault(uint _pid) internal view override returns (IStVault stVault) {
        address token = tokens[_pid];
        if (token == Const.NATIVE_ASSET) {
            stVault = AVAXVault;
        }
    }

}
