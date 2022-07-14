//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./BasicStVault.sol";

contract EthStMaticVault is BasicStVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize(
        address _treasury, address _admin,
        address _priceOracle
    ) public initializer {
        super.initialize(
            "STI L2 stMATIC", "stiL2StMATIC",
            _treasury, _admin,
            _priceOracle,
            0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0,
            0x9ee91F9f426fA633d227f7a9b000E28b9dfd8599
        );

        token.safeApprove(address(stToken), type(uint).max);
    }

    function _invest(uint _amount) internal override {}

    function _redeem() internal override {}

    function _claimUnbonded(uint _unbondedAmt) internal override {}

    function _emergencyWithdraw() internal override {}

    function _yield() internal override {}

    ///@param _amount Amount of tokens
    function getStTokenByToken(uint _amount) public override view returns(uint) {
        return Token.changeDecimals(_amount, tokenDecimals, stTokenDecimals);
    }

    ///@notice Returns the pending rewards in USD.
    function getPendingRewards() public override view returns (uint) {
        return 0;
    }

    function getAPR() public override view returns (uint) {
        return 0;
    }

    function getUnbondedToken() public override view returns (uint) {
        return 0;
    }
}
