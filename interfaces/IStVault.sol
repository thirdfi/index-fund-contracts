// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IStVault is IERC20Upgradeable {

    struct RequestWithdraw {
        uint tokenAmt;
        uint requestTs;
    }

    // fee percentage that treasury takes from rewards.
    function yieldFee() external view returns(uint);
    // treasury wallet address.
    function treasuryWallet() external view returns(address);
    // administrator address.
    function admin() external view returns(address);

    // underlying token such as ETH, WMATIC, and so on.
    function token() external view returns(address);
    // staked token such as stETH, stMATIC, and so on.
    function stToken() external view returns(address);

    // If it's true, stToken is a rebaseable ERC20 token like stETH. The holder's balance is automatically grown by reward.
    // Otherwise, stToken is a non-rebaseable token like wstETH. The holder's balance is not changed and value is grown by reward.
    function rebaseable() external view returns(bool);

    // the buffered deposit token amount that is not yet staked into the staking pool.
    function bufferedDeposits() external view returns(uint);
    // the buffered withdrawal token amount that is unstaked from the staking pool but not yet withdrawn from the user.
    function bufferedWithdrawals() external view returns(uint);
    // the total amount of withdrawal stToken that is not yet requested to the staking pool.
    function pendingRedeems() external view returns(uint);
    // the total amount of withdrawal stToken that is requested and waiting for unbonded.
    function unbondingRedeems() external view returns(uint);
    
    // the seconds to wait for unbonded since withdarwal requested. For example, 30 days in case of unstaking stDOT to get xcDOT
    function unbondingPeriod() external view returns(uint);

    // the timestamp that the last investment was executed on.
    function lastInvestTs() external view returns(uint);
    // minimum seconds to wait before next investment. For example, MetaPool's stNEAR buffer is replenished every 5 minutes.
    function investInterval() external view returns(uint);
    // the timestamp that the last redeem was requested on.
    function lastRedeemTs() external view returns(uint);
    // minimum seconds to wait before next redeem. For example, Lido have up to 20 redeem requests to stDOT in parallel. Therefore, the next redeem should be requested after about 1 day.
    function redeemInterval() external view returns(uint);

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
    ///@return the unbonded token amount that is claimable from the staking pool.
    function getUnbondedToken() external view returns (uint);

    ///@dev deposit `_amount` of token.
    function deposit(uint _amount) external;
    ///@dev request a withdrawal that corresponds to `_shares` of shares.
    function requestWithdraw(uint _shares) external;
    ///@dev stake the buffered deposits into the staking pool. It's called by admin.
    function invest() external;
    ///@dev redeem the requested withdrawals from the staking pool. It's called by admin.
    function redeem() external;
    ///@dev claim the unbonded tokens from the staking pool. It's called by admin.
    function claimUnbonded() external;
    ///@dev request a withdrawal for all staked tokens. It's called by admin.
    function emergencyWithdraw() external;
    ///@dev reinvest the tokens, and set the vault status as normal. It's called by admin.
    function reinvest() external;
    ///@dev take rewards and reinvest them. It's called by admin.
    function yield() external;
}
