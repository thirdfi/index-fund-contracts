//SPDX-License-Identifier: MIT
//
///@notice The EthStMATICVault contract stakes MATIC tokens into stMATIC on Ethereum.
///@dev https://docs.polygon.lido.fi/contracts/st-matic
//
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../BasicStVaultTest.sol";
import "../../bni/constant/EthConstantTest.sol";

contract EthStMATICVaultTest is BasicStVaultTest {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    mapping(uint => uint) public tokenIds;
    uint public first;
    uint public last;

    function initialize1(
        address _treasury, address _admin,
        address _priceOracle
    ) public initializer {
        super.initialize(
            "STI Staking MATIC", "stiStMATIC",
            _treasury, _admin,
            _priceOracle,
            EthConstantTest.MATIC,
            EthConstantTest.stMATIC
        );

        unbondingPeriod = 4 days;
        oneEpoch = 24 hours;

        first = 1;
        last = 0;

        // token.safeApprove(address(stToken), type(uint).max);
    }
}
