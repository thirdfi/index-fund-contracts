//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "../bni/priceOracle/IPriceOracle.sol";
import "../../interfaces/IERC20UpgradeableExt.sol";
import "../../interfaces/IStVault.sol";
import "../../interfaces/IStVaultNFT.sol";
import "../../libs/Const.sol";
import "../../libs/Token.sol";

contract BasicStVault is IStVault,
    ERC20Upgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint public yieldFee;
    uint public watermark;
    uint public fees;

    address public treasuryWallet;
    address public admin;
    IPriceOracle public priceOracle;
    IStVaultNFT public nft;

    IERC20Upgradeable public token;
    IERC20Upgradeable public stToken;
    uint8 internal tokenDecimals;
    uint8 internal stTokenDecimals;
    uint internal oneToken;
    uint internal oneStToken;

    uint public bufferedDeposits;
    uint public pendingWithdrawals;
    uint public pendingRedeems;
    uint internal emergencyUnbondings;

    uint public unbondingPeriod;
    uint public minInvestAmount;
    uint public minRedeemAmount;

    uint public lastInvestTs;
    uint public investInterval;
    uint public lastRedeemTs;
    uint public redeemInterval;
    uint public lastCollectProfitTs;
    uint public oneEpoch;

    mapping(address => uint) depositedBlock;
    mapping(uint => WithdrawRequest) nft2WithdrawRequest;

    uint baseApr;
    uint baseTokenRate;
    uint baseAprLastUpdate;

    event Deposit(address user, uint amount, uint shares);
    event Withdraw(address user, uint shares, uint amount, uint reqId, uint pendingAmount);
    event Claim(address user, uint reqId, uint amount);
    event ClaimMulti(address user, uint amount, uint claimedCount);
    event Invest(uint amount);
    event Redeem(uint stAmount);
    event EmergencyWithdraw(uint stAmount);
    event CollectProfitAndUpdateWatermark(uint currentWatermark, uint lastWatermark, uint fee);
    event AdjustWatermark(uint currentWatermark, uint lastWatermark);
    event TransferredOutFees(uint fees, address token);

    modifier onlyOwnerOrAdmin {
        require(msg.sender == owner() || msg.sender == admin, "Only owner or admin");
        _;
    }

    function initialize(
        string memory _name, string memory _symbol,
        address _treasury, address _admin,
        address _priceOracle,
        address _token, address _stToken
    ) public virtual initializer {
        require(_treasury != address(0), "treasury invalid");

        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __ERC20_init_unchained(_name, _symbol);

        yieldFee = 2000; //20%
        treasuryWallet = _treasury;
        admin = _admin;
        priceOracle = IPriceOracle(_priceOracle);

        token = IERC20Upgradeable(_token);
        stToken = IERC20Upgradeable(_stToken);
        tokenDecimals = _assetDecimals(address(token));
        stTokenDecimals = IERC20UpgradeableExt(address(stToken)).decimals();
        oneToken = 10**tokenDecimals;
        oneStToken = 10**stTokenDecimals;

        minInvestAmount = 1;
        minRedeemAmount = 1;

        _updateApr();
    }

    ///@notice Function to set deposit and yield fee
    ///@param _yieldFeePerc deposit fee percentage. 2000 for 20%
    function setFee(uint _yieldFeePerc) external onlyOwner{
        require(_yieldFeePerc < 3001, "Yield Fee cannot > 30%");
        yieldFee = _yieldFeePerc;
    }

    function setTreasuryWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0), "wallet invalid");
        treasuryWallet = _wallet;
    }

    function setAdmin(address _newAdmin) external onlyOwner{
        admin = _newAdmin;
    }

    function setNFT(address _nft) external onlyOwner {
        require(address(nft) == address(0), "Already set");
        nft = IStVaultNFT(_nft);
    }

    function setStakingPeriods(
        uint _unbondingPeriod,
        uint _investInterval,
        uint _redeemInterval,
        uint _oneEpoch
    ) external onlyOwner {
        unbondingPeriod = _unbondingPeriod;
        investInterval = _investInterval;
        redeemInterval = _redeemInterval;
        oneEpoch = _oneEpoch;
    }

    function setStakingAmounts(uint _minInvestAmount, uint _minRedeemAmount) external onlyOwner {
        require(_minInvestAmount > 0, "minInvestAmount must be > 0");
        require(_minRedeemAmount > 0, "minRedeemAmount must be > 0");
        minInvestAmount = _minInvestAmount;
        minRedeemAmount = _minRedeemAmount;
    }

    function deposit(uint _amount) external nonReentrant whenNotPaused{
        _deposit(msg.sender, _amount);
    }

    function depositETH() external payable nonReentrant whenNotPaused{
        _deposit(msg.sender, msg.value);
    }

    function _deposit(address _account, uint _amount) internal {
        require(_amount > 0, "Invalid amount");
        depositedBlock[_account] = block.number;

        if (address(token) != Const.NATIVE_ASSET) {
            token.safeTransferFrom(_account, address(this), _amount);
        } else {
            // The native asset is already received.
        }
        bufferedDeposits += _amount;

        uint pool = getAllPool() - _amount;
        uint _totalSupply = totalSupply();
        uint _shares = (_totalSupply == 0) ? _amount : _amount * _totalSupply / pool;

        _mint(_account, _shares);
        adjustWatermark(_amount, true);
        emit Deposit(_account, _amount, _shares);
    }

    function withdraw(uint _shares) external nonReentrant returns (uint _amount, uint _reqId) {
        require(_shares > 0, "Invalid Amount");
        require(balanceOf(msg.sender) >= _shares, "Not enough balance");
        require(depositedBlock[msg.sender] != block.number, "Withdraw within same block");

        uint withdrawAmt = getPoolByShares(_shares);
        _burn(msg.sender, _shares);
        adjustWatermark(withdrawAmt, false);

        uint _bufferedDeposits = getBufferedDeposits();
        uint _fees = fees;
        uint _buffered = (_bufferedDeposits <= _fees) ? 0 : _bufferedDeposits - fees;

        if (_buffered >= withdrawAmt) {
            _amount = withdrawAmt;
            withdrawAmt = 0;
        } else {
            _amount = _buffered;
            withdrawAmt -= _buffered;
        }

        bufferedDeposits = _bufferedDeposits - _amount;

        if (withdrawAmt > 0) {
            uint stTokenAmt = oneStToken * withdrawAmt / getPooledTokenByStToken(oneStToken);
            (uint withdrawnStAmount, uint withdrawnAmount) = withdrawStToken(stTokenAmt);
            if (withdrawnStAmount > 0) {
                _amount += withdrawnAmount;
                uint prevStTokenAmt = stTokenAmt;
                stTokenAmt -= withdrawnStAmount;
                withdrawAmt = withdrawAmt * stTokenAmt / prevStTokenAmt;
            }

            if (stTokenAmt > 0) {
                pendingWithdrawals += withdrawAmt;
                if (paused() == false) {
                    pendingRedeems += stTokenAmt;
                } else {
                    // We reduce the emergency bonding because the share is burnt.
                    uint _emergencyUnbondings = getEmergencyUnbondings();
                    emergencyUnbondings = (_emergencyUnbondings <= stTokenAmt) ? 0 : _emergencyUnbondings - stTokenAmt;
                }

                _reqId = nft.mint(msg.sender);
                nft2WithdrawRequest[_reqId] = WithdrawRequest({
                    tokenAmt: withdrawAmt,
                    stTokenAmt: stTokenAmt,
                    requestTs: block.timestamp
                });
            }
        }

        if (_amount > 0) {
            _transferOutToken(msg.sender, _amount);
        }
        emit Withdraw(msg.sender, _shares, _amount, _reqId, withdrawAmt);
    }

    function withdrawStToken(uint _stAmountToWithdraw) internal virtual returns (
        uint _withdrawnStAmount,
        uint _withdrawnAmount
    ) {
    }

    function claim(uint _reqId) external nonReentrant returns (uint _amount) {
        require(nft.isApprovedOrOwner(msg.sender, _reqId), "Not owner");
        WithdrawRequest memory usersRequest = nft2WithdrawRequest[_reqId];

        require(block.timestamp >= (usersRequest.requestTs + unbondingPeriod), "Not able to claim yet");

        _amount = usersRequest.tokenAmt;
        require(bufferedWithdrawals() >= _amount, "No enough token");

        nft.burn(_reqId);
        _transferOutToken(msg.sender, _amount);

        pendingWithdrawals -= _amount;
        emit Claim(msg.sender, _reqId, _amount);
    }

    function claimMulti(uint[] memory _reqIds) external nonReentrant returns (
        uint _amount,
        uint _claimedCount,
        bool[] memory _claimed
    ) {
        uint buffered = bufferedWithdrawals();
        uint amount;
        uint length = _reqIds.length;
        _claimed = new bool[](length);

        for (uint i = 0; i < length; i++) {
            uint _reqId = _reqIds[i];
            if (nft.isApprovedOrOwner(msg.sender, _reqId) == false) continue;

            WithdrawRequest memory usersRequest = nft2WithdrawRequest[_reqId];
            if (block.timestamp < (usersRequest.requestTs + unbondingPeriod)) continue;

            amount = usersRequest.tokenAmt;
            if (buffered < amount) continue;

            _amount += amount;
            buffered -= amount;

            nft.burn(_reqId);
            _claimedCount ++;
            _claimed[i] = true;
        }

        if (_amount > 0) {
            _transferOutToken(msg.sender, _amount);
            pendingWithdrawals -= _amount;
            emit ClaimMulti(msg.sender, _amount, _claimedCount);
        }
    }

    function invest() external onlyOwnerOrAdmin whenNotPaused {
        _investInternal();
    }
    function _investInternal() internal {
        _collectProfitAndUpdateWatermark();
        uint _buffered = _transferOutFees();
        if (_buffered >= minInvestAmount && block.timestamp >= (lastInvestTs + investInterval)) {
            uint _invested = _invest(_buffered);
            bufferedDeposits = _buffered - _invested;
            lastInvestTs = block.timestamp;
            emit Invest(_invested);
        }
    }
    function _invest(uint _amount) internal virtual returns (uint _invested) {}

    function redeem() external onlyOwnerOrAdmin whenNotPaused {
        uint redeemed = _redeemInternal(pendingRedeems);
        pendingRedeems -= redeemed;
    }
    function _redeemInternal(uint _stAmount) internal returns (uint _redeemed) {
        require(_stAmount >= minRedeemAmount, "too small");
        require(block.timestamp >= (lastRedeemTs + redeemInterval), "Not able to redeem yet");

        _redeemed = _redeem(_stAmount);
        emit Redeem(_redeemed);
    }
    function _redeem(uint _stAmount) internal virtual returns (uint _redeemed) {}

    function claimUnbonded() external onlyOwnerOrAdmin {
        _claimUnbonded();
    }
    function _claimUnbonded() internal virtual {}

    ///@notice Withdraws funds staked in mirror to this vault and pauses deposit, yield, invest functions
    function emergencyWithdraw() external onlyOwnerOrAdmin whenNotPaused {
        _pause();
        _yield();

        _emergencyWithdrawInternal();
    }
    function _emergencyWithdrawInternal() internal {
        uint _pendingRedeems = pendingRedeems;
        uint redeemed = _emergencyWithdraw(_pendingRedeems);
        pendingRedeems = (_pendingRedeems <= redeemed) ? 0 : _pendingRedeems - redeemed;
        emit EmergencyWithdraw(redeemed);
    }
    function _emergencyWithdraw(uint _pendingRedeems) internal virtual returns (uint _redeemed) {}

    function emergencyRedeem() external onlyOwnerOrAdmin whenPaused {
        _emergencyWithdrawInternal();
    }

    ///@notice Unpauses deposit, yield, invest functions, and invests funds.
    function reinvest() external onlyOwnerOrAdmin whenPaused {
        require(getEmergencyUnbondings() == 0, "Emergency unbonding is not finished");
        require(getTokenUnbonded() == 0, "claimUnbonded should be called");
        _unpause();

        emergencyUnbondings = 0;
        _investInternal();
    }

    function yield() external onlyOwnerOrAdmin whenNotPaused {
        _yield();
    }
    function _yield() internal virtual {}

    function collectProfitAndUpdateWatermark() external onlyOwnerOrAdmin whenNotPaused {
        _collectProfitAndUpdateWatermark();
    }
    function _collectProfitAndUpdateWatermark() private {
        uint currentWatermark = getAllPool();
        uint lastWatermark = watermark;
        uint fee;
        if (currentWatermark > lastWatermark) {
            uint profit = currentWatermark - lastWatermark;
            fee = profit * yieldFee / Const.DENOMINATOR;
            fees += fee;
            watermark = currentWatermark - fee;
        }
        lastCollectProfitTs = block.timestamp;
        emit CollectProfitAndUpdateWatermark(currentWatermark, lastWatermark, fee);
    }

    /// @param signs True for positive, false for negative
    function adjustWatermark(uint amount, bool signs) private {
        uint lastWatermark = watermark;
        watermark = signs == true
                    ? watermark + amount
                    : (watermark > amount) ? watermark - amount : 0;
        emit AdjustWatermark(watermark, lastWatermark);
    }

    function withdrawFees() external onlyOwnerOrAdmin {
        _transferOutFees();
    }

    function _transferOutFees() internal returns (uint _tokenAmt) {
        _tokenAmt = getBufferedDeposits();
        uint _fees = fees;
        if (_fees != 0 && _tokenAmt != 0) {
            uint feeAmt = _fees;
            if (feeAmt < _tokenAmt) {
                _fees = 0;
                _tokenAmt -= feeAmt;
            } else {
                _fees -= _tokenAmt;
                feeAmt = _tokenAmt;
                _tokenAmt = 0;
            }
            fees = _fees;

            _transferOutToken(treasuryWallet, feeAmt);
            bufferedDeposits = _tokenAmt;
            emit TransferredOutFees(feeAmt, address(token)); // Decimal follows token
        }
    }

    function _transferOutToken(address _to, uint _amount) internal {
        (address(token) != Const.NATIVE_ASSET)
            ? token.safeTransfer(_to, _amount)
            : Token.safeTransferETH(_to, _amount);
    }

    function _tokenBalanceOf(address _account) internal view returns (uint) {
        return (address(token) != Const.NATIVE_ASSET)
            ? token.balanceOf(_account)
            : _account.balance;
    }

    function _assetDecimals(address _asset) internal view returns (uint8 _decimals) {
        _decimals = (_asset == Const.NATIVE_ASSET) ? 18 : IERC20UpgradeableExt(_asset).decimals();
    }

    function _getFreeBufferedDeposits() internal view returns (uint _buffered) {
        uint balance = _tokenBalanceOf(address(this));
        uint _pendingWithdrawals = pendingWithdrawals;
        // While unbonding, the balance could be less than pendingWithdrawals.
        // After unbonded, the balance could be greater than pendingWithdrawals
        //  because the rewards are accumulated in unbonding period on some staking pools.
        //  In this case, the _buffered can be greater than bufferedDeposits.
        // And also if the emergency withdrawal is unbonded, the _buffered will be greater than bufferedDeposits.
        _buffered = (balance > _pendingWithdrawals) ? balance - _pendingWithdrawals : 0;
    }

    function getBufferedDeposits() public virtual view returns (uint) {
        return MathUpgradeable.max(bufferedDeposits, _getFreeBufferedDeposits());
    }

    function bufferedWithdrawals() public view returns (uint) {
        return _tokenBalanceOf(address(this)) - bufferedDeposits;
    }

    function getEmergencyUnbondings() public virtual view returns (uint) {
        return emergencyUnbondings;
    }

    function getInvestedStTokens() public virtual view returns (uint _stAmount) {
        return 0;
    }

    ///@param _amount Amount of tokens
    function getStTokenByPooledToken(uint _amount) public virtual view returns(uint) {
        return Token.changeDecimals(_amount, tokenDecimals, stTokenDecimals);
    }

    ///@param _stAmount Amount of stTokens
    function getPooledTokenByStToken(uint _stAmount) public virtual view returns(uint) {
        return _stAmount * oneToken / getStTokenByPooledToken(oneToken);
    }

    ///@dev it doesn't include the unbonding stTokens according to the burnt shares.
    function getAllPool() public virtual view returns (uint _pool) {
        if (paused() == false) {
            uint stBalance = stToken.balanceOf(address(this))
                            + getInvestedStTokens()
                            - pendingRedeems;
            if (stBalance > 0) {
                _pool = getPooledTokenByStToken(stBalance);
            }
            _pool += bufferedDeposits;
            _pool -= fees;
        } else {
            uint stBalance = stToken.balanceOf(address(this))
                            + getInvestedStTokens()
                            + getEmergencyUnbondings()
                            - pendingRedeems;
            if (stBalance > 0) {
                _pool = getPooledTokenByStToken(stBalance);
            }
            // If the emergency withdrawal is unbonded,
            //  then getEmergencyUnbondings() is less than emergencyUnbondings,
            //  and _getFreeBufferedDeposits will be greater than bufferedDeposits.
            _pool += _getFreeBufferedDeposits();
            _pool -= fees;
        }
    }

    function getSharesByPool(uint _amount) public view returns (uint) {
        uint pool = getAllPool();
        return (pool == 0) ? _amount : _amount * totalSupply() / pool;
    }

    function getPoolByShares(uint _shares) public view returns (uint) {
        uint _totalSupply = totalSupply();
        return (_totalSupply == 0) ? _shares : _shares * getAllPool() / _totalSupply;
    }

    function getAllPoolInUSD() public view returns (uint) {
        uint pool = getAllPool();
        return getValueInUSD(address(token), pool);
    }

    ///@return the value in USD. it's scaled by 1e18;
    function getValueInUSD(address _asset, uint _amount) internal view returns (uint) {
        (uint priceInUSD, uint8 priceDecimals) = priceOracle.getAssetPrice(_asset);
        uint8 _decimals = _assetDecimals(_asset);
        return Token.changeDecimals(_amount, _decimals, 18) * priceInUSD / (10 ** (priceDecimals));
    }

    ///@notice Returns the pending rewards in USD.
    function getPendingRewards() public virtual view returns (uint) {
        return 0;
    }

    function getAPR() public virtual view returns (uint) {
        (uint _baseApr,,) = getBaseApr();
        return _baseApr;
    }

    function resetApr() external onlyOwner {
        _resetApr();
        _updateApr();
    }

    function _resetApr() internal virtual {
        baseApr = 0;
        baseTokenRate = 0;
        baseAprLastUpdate = 0;
    }

    function _updateApr() internal virtual {
        (uint _baseApr, uint _baseTokenRate, bool _update) = getBaseApr();
        if (_update) {
            baseApr = _baseApr;
            baseTokenRate = _baseTokenRate;
            baseAprLastUpdate = block.timestamp;
        }
    }

    function getBaseApr() public view returns (uint, uint, bool) {
        uint _baseApr = baseApr;
        uint _baseTokenRate = baseTokenRate;
        uint _baseAprLastUpdate = baseAprLastUpdate;

        if (_baseApr == 0 || (_baseAprLastUpdate + 1 weeks) <= block.timestamp) {
            uint newTokenRate = getPoolByShares(1e18);
            if (0 < _baseTokenRate && _baseTokenRate < newTokenRate) {
                uint newApr = (newTokenRate-_baseTokenRate) * Const.YEAR_IN_SEC * Const.APR_SCALE
                            / (_baseTokenRate * (block.timestamp-_baseAprLastUpdate));
                return (newApr, newTokenRate, true);
            } else {
                return (0, newTokenRate, true);
            }
        } else {
            return (_baseApr, _baseTokenRate, false);
        }
    }

    function getBaseAprData() public view returns (uint, uint, uint) {
        return (baseApr, baseTokenRate, baseAprLastUpdate);
    }

    function getWithdrawRequest(uint _reqId) external view returns (
        bool _claimable,
        uint _tokenAmt, uint _stTokenAmt,
        uint _requestTs, uint _waitForTs
    ) {
        WithdrawRequest memory usersRequest = nft2WithdrawRequest[_reqId];
        _tokenAmt = usersRequest.tokenAmt;
        _stTokenAmt = usersRequest.stTokenAmt;
        _requestTs = usersRequest.requestTs;

        uint endTs = _requestTs + unbondingPeriod;
        if (endTs > block.timestamp) {
            _waitForTs = endTs - block.timestamp;
        } else if (bufferedWithdrawals() >= _tokenAmt) {
            _claimable = true;
        }
    }

    function getTokenUnbonded() public virtual view returns (uint) {
        return 0;
    }

    receive() external payable {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[20] private __gap;
}
