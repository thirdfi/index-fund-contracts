//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./BasicCompoundVault.sol";
import "../../../interfaces/IERC20UpgradeableExt.sol";
import "../../../interfaces/IUniRouter.sol";
import "../../../libs/Const.sol";

interface IBastionComptroller {
    function rewardDistributor() external view returns (address);
}

struct RewardMarketState {
    /// @notice The market's last updated borrowIndex or supplyIndex
    uint224 index;
    /// @notice The timestamp number the index was last updated at
    uint32 timestamp;
}

interface IRewardDistributor {
    function getRewardAddress(uint rewardType) external view returns (address);
    function rewardSupplySpeeds(uint8 rewardType, address cToken) external view returns (uint);
    function rewardSupplyState(uint8 rewardType,  address cToken) external view returns (RewardMarketState memory);
    function rewardSupplierIndex(uint8 rewardType, address cToken, address supplier) external view returns(uint);
    function rewardAccrued(uint8 rewardType, address supplyer) external view returns(uint);

    function claimReward(uint8 rewardType, address holder, address[] memory cTokens) external;
}

contract AuroraBastionVault is BasicCompoundVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant WNEAR = IERC20Upgradeable(0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d);

    IUniRouter public constant Router = IUniRouter(0x2CB45Edb4517d5947aFdE3BEAbF95A582506858B); // Trisolaris

    uint constant REWARD_COUNT = 2;
    uint constant doubleScale = 1e36;
    uint constant rewardInitialIndex = 1e36;
    IRewardDistributor public rewardDistributor;

    event YieldFee(uint _amount);
    event Yield(uint _amount);

    function initialize(string memory _name, string memory _symbol, 
        address _treasury, address _admin,
        address _priceOracle,
        ICToken _cToken
    ) public virtual override initializer {
        super.initialize(_name, _symbol, _treasury, _admin, _priceOracle, _cToken);

        _updateRewardDistributor();
    }

    function _updateRewardDistributor() private {
        rewardDistributor = IRewardDistributor(IBastionComptroller(address(comptroller)).rewardDistributor());
        // It needs to approve router for reward token
        for (uint8 rewardType = 0; rewardType < REWARD_COUNT; rewardType ++) {
            address reward = rewardDistributor.getRewardAddress(rewardType);
            IERC20Upgradeable(reward).safeApprove(address(Router), type(uint).max);
        }
    }
    function updateRewardDistributor() external onlyOwner {
        _updateRewardDistributor();
    }

    function _yield() internal override {
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cToken);

        for (uint8 rewardType = 0; rewardType < REWARD_COUNT; rewardType ++) {
            rewardDistributor.claimReward(rewardType, address(this), cTokens);
            address reward = rewardDistributor.getRewardAddress(rewardType);
            uint amount = IERC20Upgradeable(reward).balanceOf(address(this));
            if (0 < amount) {
                uint fee = amount * yieldFee / Const.DENOMINATOR; //yield fee
                IERC20Upgradeable(reward).safeTransfer(treasuryWallet, fee);
                amount -= fee;

                if (address(token) != reward) {
                    if (token == WNEAR || reward == address(WNEAR)) {
                        _swap(reward, address(token), amount);
                    } else {
                        _swap2(reward, address(token), amount);
                    }
                }
                uint rewardInUSD = getValueInUSD(reward, amount+fee);
                emit Yield(rewardInUSD);
                emit YieldFee(rewardInUSD * yieldFee / Const.DENOMINATOR);
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
        path[1] = address(WNEAR);
        path[2] = address(_tokenB);
        return Router.swapExactTokensForTokens(_amt, 0, path, address(this), block.timestamp)[2];
    }

    function getPendingRewards() public view override returns (uint) {
        uint pending;
        for (uint8 rewardType = 0; rewardType < REWARD_COUNT; rewardType ++) {
            uint amount = _getPendingRewardAmount(rewardType);
            if (amount > 0) {
                address reward = rewardDistributor.getRewardAddress(rewardType);
                pending += getValueInUSD(reward, amount);
            }
        }
        return pending;
    }

    function _getPendingRewardAmount(uint8 rewardType) private view returns (uint supplierAccrued) {
        RewardMarketState memory supplyState = rewardDistributor.rewardSupplyState(rewardType, address(cToken));
        uint supplySpeed = rewardDistributor.rewardSupplySpeeds(rewardType, address(cToken));
        uint256 deltaTimestamps = block.timestamp - uint(supplyState.timestamp);
        if (deltaTimestamps > 0 && supplySpeed > 0) {
            uint supplyTokens = cToken.totalSupply();
            uint _rewardAccrued = deltaTimestamps * supplySpeed;
            uint ratio = supplyTokens > 0
                ? _rewardAccrued * doubleScale / supplyTokens
                : 0;
            uint supplyIndex = uint(supplyState.index) + ratio;
            uint supplierIndex = rewardDistributor.rewardSupplierIndex(rewardType, address(cToken), address(this));
            if (supplierIndex == 0 && supplyIndex > 0) {
                supplierIndex = rewardInitialIndex;
            }
            uint deltaIndex = supplyIndex - supplierIndex;
            uint supplierDelta = cToken.balanceOf(address(this)) * deltaIndex / doubleScale;
            supplierAccrued = rewardDistributor.rewardAccrued(rewardType, address(this)) + supplierDelta;
        }
    }

    function getBlocksPerYear() public view override returns (uint) {
        return 28_908_000; //55 * 60 * 24 * 365;
    }

    function getAPR() public view virtual override returns (uint) {
        uint rewardsPerYear;
        for (uint rewardType = 0; rewardType < REWARD_COUNT; rewardType ++) {
            uint supplySpeed = rewardDistributor.rewardSupplySpeeds(uint8(rewardType), address(cToken));
            if (supplySpeed > 0) {
                address reward = rewardDistributor.getRewardAddress(rewardType);
                rewardsPerYear += getValueInUSD(reward, supplySpeed * Const.YEAR_IN_SEC);
            }
        }
        if (rewardsPerYear > 0) {
            uint underlyingSupply = (cToken.totalSupply() * cToken.exchangeRateStored()) / MANTISSA_ONE;
            uint rewardsApr = rewardsPerYear * 1e18 / getValueInUSD(address(token), underlyingSupply);
            return super.getAPR() + (rewardsApr * (Const.DENOMINATOR-yieldFee) / Const.DENOMINATOR);
        } else {
            return super.getAPR();
        }
    }
}
