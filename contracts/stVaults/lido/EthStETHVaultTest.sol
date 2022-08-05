//SPDX-License-Identifier: MIT
//
///@notice The EthStETHVault contract stakes ETH tokens into stETH on Ethereum.
///@dev https://docs.polkadot.lido.fi/fundamentals/liquid-staking
//
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../BasicStVaultTest.sol";
import "../../bni/constant/EthConstantTest.sol";
import "../../../libs/Const.sol";

contract EthStETHVaultTest is BasicStVaultTest {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize1(
        address _treasury, address _admin,
        address _priceOracle
    ) public initializer {
        super.initialize(
            "STI Staking ETH", "stiStETH",
            _treasury, _admin,
            _priceOracle,
            Const.NATIVE_ASSET, // ETH
            EthConstantTest.stETH
        );

        oneEpoch = 24 hours;

        // stToken.safeApprove(address(curveStEth), type(uint).max);
    }
}
