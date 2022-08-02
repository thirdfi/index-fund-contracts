// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IStVault is IERC20Upgradeable {

    struct WithdrawRequest {
        uint tokenAmt;
        uint stTokenAmt;
        uint requestTs;
    }

    // fee percentage that treasury takes from rewards.
    function yieldFee() external view returns(uint);
    // treasury wallet address.
    function treasuryWallet() external view returns(address);
    // administrator address.
    function admin() external view returns(address);

    // underlying token such as ETH, WMATIC, and so on.
    function token() external view returns(IERC20Upgradeable);
    // staked token such as stETH, stMATIC, and so on.
    function stToken() external view returns(IERC20Upgradeable);

    // the buffered deposit token amount that is not yet staked into the staking pool.
    function bufferedDeposits() external view returns(uint);
    // On some staking pools, the rewards are accumulated until unbonded even though redeem is requested. This function considers it.
    function getBufferedDeposits() external view returns(uint);
    // the buffered withdrawal token amount that is unstaked from the staking pool but not yet withdrawn from the user.
    function bufferedWithdrawals() external view returns(uint);
    // the token amount that shares is already burnt but not withdrawn.
    function pendingWithdrawals() external view returns(uint);
    // the total amount of withdrawal stToken that is not yet requested to the staking pool.
    function pendingRedeems() external view returns(uint);
    // the amount of stToken that is emergency unbonding, and shares according to them are not burnt yet.
    function getEmergencyUnbondings() external view returns(uint);
    // the amount of stToken that has invested into L2 vaults to get extra benefit.
    function getInvestedStTokens() external view returns(uint);
    
    // the seconds to wait for unbonded since withdarwal requested. For example, 30 days in case of unstaking stDOT to get xcDOT
    function unbondingPeriod() external view returns(uint);
    // the minimum amount of token to invest.
    function minInvestAmount() external view returns(uint);
    // the minimum amount of stToken to redeem.
    function minRedeemAmount() external view returns(uint);

    // the timestamp that the last investment was executed on.
    function lastInvestTs() external view returns(uint);
    // minimum seconds to wait before next investment. For example, MetaPool's stNEAR buffer is replenished every 5 minutes.
    function investInterval() external view returns(uint);
    // the timestamp that the last redeem was requested on.
    function lastRedeemTs() external view returns(uint);
    // minimum seconds to wait before next redeem. For example, Lido have up to 20 redeem requests to stDOT in parallel. Therefore, the next redeem should be requested after about 1 day.
    function redeemInterval() external view returns(uint);
    // the timestamp that the profit last collected on.
    function lastCollectProfitTs() external view returns(uint);
    // the timestamp of one epoch. Each epoch, the stToken price or balance will increase as staking-rewards are added to the pool.
    function oneEpoch() external view returns(uint);

    ///@return the total amount of tokens in the vault.
    function getAllPool() external view returns (uint);
    ///@return the amount of shares that corresponds to `_amount` of token.
    function getSharesByPool(uint _amount) external view returns (uint);
    ///@return the amount of token that corresponds to `_shares` of shares.
    function getPoolByShares(uint _shares) external view returns (uint);
    ///@return the total USD value of tokens in the vault.
    function getAllPoolInUSD() external view returns (uint);
    ///@return the USD value of rewards that is avilable to claim. It's scaled by 1e18.
    function getPendingRewards() external view returns (uint);
    ///@return the APR in the vault. It's scaled by 1e18.
    function getAPR() external view returns (uint);
    ///@return _claimable specifys whether user can claim tokens for it.
    ///@return _tokenAmt is amount of token to claim.
    ///@return _stTokenAmt is amount of stToken to redeem.
    ///@return _requestTs is timestmap when withdrawal requested.
    ///@return _waitForTs is timestamp to wait for.
    function getWithdrawRequest(uint _reqId) external view returns (
        bool _claimable,
        uint _tokenAmt, uint _stTokenAmt,
        uint _requestTs, uint _waitForTs
    );
    ///@return the unbonded token amount that is claimable from the staking pool.
    function getTokenUnbonded() external view returns (uint);

    ///@dev deposit `_amount` of token.
    function deposit(uint _amount) external;
    ///@dev deposit the native asset.
    function depositETH() external payable;
    ///@dev request a withdrawal that corresponds to `_shares` of shares.
    ///@return _amount is the amount of withdrawn token.
    ///@return _reqId is the NFT token id indicating the request for rest of withdrawal. 0 if no request is made.
    function withdraw(uint _shares) external returns (uint _amount, uint _reqId);
    ///@dev claim token with NFT token
    ///@return _amount is the amount of claimed token.
    function claim(uint _reqId) external returns (uint _amount);
    ///@dev claim token with NFT tokens
    ///@return _amount is the amount of claimed token.
    ///@return _claimedCount is the count of reqIds that are claimed.
    ///@return _claimed is the flag indicating whether the token is claimed.
    function claimMulti(uint[] memory _reqIds) external returns (uint _amount, uint _claimedCount, bool[] memory _claimed);
    ///@dev stake the buffered deposits into the staking pool. It's called by admin.
    function invest() external;
    ///@dev redeem the requested withdrawals from the staking pool. It's called by admin.
    function redeem() external;
    ///@dev claim the unbonded tokens from the staking pool. It's called by admin.
    function claimUnbonded() external;
    ///@dev request a withdrawal for all staked tokens. It's called by admin.
    function emergencyWithdraw() external;
    ///@dev the total amount of emergency withdrawal stToken that is not yet requested to the staking pool.
    function emergencyPendingRedeems() external view returns (uint _redeems);
    ///@dev In emergency mode, redeem the rest of stTokens. Especially it's needed for stNEAR because the MetaPool has a buffer limit.
    function emergencyRedeem() external;
    ///@dev reinvest the tokens, and set the vault status as normal. It's called by admin.
    function reinvest() external;
    ///@dev take rewards and reinvest them. It's called by admin.
    function yield() external;
    ///@dev collect profit and update the watermark
    function collectProfitAndUpdateWatermark() external;
    ///@dev transfer out fees.
    function withdrawFees() external;
}
