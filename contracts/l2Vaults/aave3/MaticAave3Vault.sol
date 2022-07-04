//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./BasicAave3Vault.sol";
import "../../../interfaces/IERC20UpgradeableExt.sol";
import "../../../interfaces/IUniRouter.sol";

contract MaticAave3Vault is BasicAave3Vault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant WMATIC = IERC20Upgradeable(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

    IUniRouter public constant Router = IUniRouter(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

    event YieldFee(uint _amount);
    event Yield(uint _amount);

    function initialize(string memory _name, string memory _symbol, 
        address _treasury, address _admin,
        address _priceOracle,
        IAToken _aToken
    ) public virtual override initializer {
        super.initialize(_name, _symbol, _treasury, _admin, _priceOracle, _aToken);

        // It needs to approve router for reward token
    }

    function _yield() internal override {
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);
        (address[] memory rewards, uint[] memory amounts) = aRewardsController.claimAllRewardsToSelf(assets);

        uint rewardsCount = rewards.length;
        for (uint i = 0; i < rewardsCount; i ++) {
            address reward = rewards[i];
            uint amount = amounts[i];
            if (0 < amount) {
                uint fee = amount * yieldFee / DENOMINATOR; //yield fee
                IERC20Upgradeable(reward).safeTransfer(treasuryWallet, fee);
                amount -= fee;

                // It needs to approve router for reward token
                if (IERC20Upgradeable(reward).allowance(address(this), address(Router)) < amount) {
                    IERC20Upgradeable(reward).safeApprove(address(Router), type(uint).max);
                }

                if (address(token) != reward) {
                    if (token == WMATIC || reward == address(WMATIC)) {
                        _swap(reward, address(token), amount);
                    } else {
                        _swap2(reward, address(token), amount);
                    }
                }
                uint rewardInUSD = getValueInUSD(reward, amount+fee);
                emit Yield(rewardInUSD);
                emit YieldFee(rewardInUSD * yieldFee / DENOMINATOR);
            }
        }

        _invest();
    }

    function _swap(address _tokenA, address _tokenB, uint _amt) private returns (uint){
        address[] memory path = new address[](2);
        path[0] = address(_tokenA);
        path[1] = address(_tokenB);
        return Router.swapExactTokensForTokens(_amt, 0, path, address(this), block.timestamp)[1];
    }

    function _swap2(address _tokenA, address _tokenB, uint _amt) private returns (uint){
        address[] memory path = new address[](3);
        path[0] = address(_tokenA);
        path[1] = address(WMATIC);
        path[2] = address(_tokenB);
        return Router.swapExactTokensForTokens(_amt, 0, path, address(this), block.timestamp)[2];
    }
}
