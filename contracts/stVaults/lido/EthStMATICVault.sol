//SPDX-License-Identifier: MIT
//
///@notice The EthStMATICVault contract stakes MATIC tokens into stMATIC on Ethereum.
///@dev https://docs.polygon.lido.fi/contracts/st-matic
//
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../BasicStVault.sol";
import "../../bni/constant/EthConstant.sol";

interface IStakeManager {
    function epoch() external view returns (uint);
}

interface IPoLidoNFT {
    function getOwnedTokens(address _address) external view returns (uint[] memory);
    function tokenIdIndex() external view returns (uint);
}

struct StMATIC_RequestWithdraw {
    uint amount2WithdrawFromStMATIC;
    uint validatorNonce;
    uint requestEpoch;
    address validatorAddress;
}

interface IStMATIC {
    function token2WithdrawRequest(uint _tokenId) external view returns (StMATIC_RequestWithdraw memory);
    function stakeManager() external view returns (IStakeManager);
    function poLidoNFT() external view returns (IPoLidoNFT);
    function convertStMaticToMatic(uint _balance) external view returns (uint balanceInMatic, uint totalShares, uint totalPooledMatic);
    function convertMaticToStMatic(uint _balance) external view returns (uint balanceInStMatic, uint totalShares, uint totalPooledMatic);
    function getMaticFromTokenId(uint _tokenId) external view returns (uint);

    function submit(uint _amount) external returns (uint);
    function requestWithdraw(uint _amount) external;
    function claimTokens(uint _tokenId) external;
}

contract EthStMATICVault is BasicStVault {
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
            EthConstant.MATIC,
            EthConstant.stMATIC
        );

        unbondingPeriod = 4 days;
        oneEpoch = 24 hours;

        first = 1;
        last = 0;

        token.safeApprove(address(stToken), type(uint).max);
    }

    function _enqueue(uint _tokenId) private {
        last += 1;
        tokenIds[last] = _tokenId;
    }

    function _dequeue() private returns (uint _tokenId) {
        require(last >= first);  // non-empty queue
        _tokenId = tokenIds[first];
        delete tokenIds[first];
        first += 1;
    }

    function _invest(uint _amount) internal override returns (uint _invested) {
        IStMATIC(address(stToken)).submit(_amount);
        return _amount;
    }

    function _redeem(uint _stAmount) internal override returns (uint _redeemed) {
        // Because _stAmount-stBalance may be a calculation delta in withdraw function,
        // it will reduce the pendingRedeems even though no redeeming on the staking pool.
        _redeemed = _stAmount;

        uint stBalance = stToken.balanceOf(address(this));
        _requestRedeem(_stAmount > stBalance ? stBalance : _stAmount);
    }

    function _requestRedeem(uint _stAmount) internal {
        IStMATIC(address(stToken)).requestWithdraw(_stAmount);

        IPoLidoNFT poLidoNFT = IStMATIC(address(stToken)).poLidoNFT();
        _enqueue(poLidoNFT.tokenIdIndex());
    }

    function _claimUnbonded() internal override {
        IStakeManager stakeManager = IStMATIC(address(stToken)).stakeManager();
        uint epoch = stakeManager.epoch();

        while (first <= last) {
            StMATIC_RequestWithdraw memory request = IStMATIC(address(stToken)).token2WithdrawRequest(tokenIds[first]);
            if (epoch < request.requestEpoch) {
                // Not able to claim yet
                break;
            }
            IStMATIC(address(stToken)).claimTokens(_dequeue());
        }

        if (last < first && paused()) {
            // The tokens according to the emergency unbonding has been claimed
            emergencyUnbondings = 0;
        }
    }

    function _emergencyWithdraw(uint _pendingRedeems) internal override returns (uint _redeemed) {
        uint stBalance = stToken.balanceOf(address(this));
        if (stBalance >= minRedeemAmount) {
            _requestRedeem(stBalance);
            emergencyUnbondings = (stBalance > _pendingRedeems) ? stBalance - _pendingRedeems : 0;
            _redeemed = stBalance;
        }
    }

    ///@param _amount Amount of tokens
    function getStTokenByPooledToken(uint _amount) public override view returns(uint) {
        (uint balanceInStMatic,,) = IStMATIC(address(stToken)).convertMaticToStMatic(_amount);
        return balanceInStMatic;
    }

    ///@param _stAmount Amount of stTokens
    function getPooledTokenByStToken(uint _stAmount) public override view returns(uint) {
        (uint balanceInMatic,,) = IStMATIC(address(stToken)).convertStMaticToMatic(_stAmount);
        return balanceInMatic;
    }

    function getTokenUnbonded() public override view returns (uint _amount) {
        IStakeManager stakeManager = IStMATIC(address(stToken)).stakeManager();
        uint epoch = stakeManager.epoch();

        for (uint i = first; i <= last; i ++) {
            uint tokenId = tokenIds[i];
            StMATIC_RequestWithdraw memory request = IStMATIC(address(stToken)).token2WithdrawRequest(tokenId);
            if (epoch < request.requestEpoch) {
                // Not able to claim yet
                break;
            }
            _amount += IStMATIC(address(stToken)).getMaticFromTokenId(tokenId);
        }
    }
}
