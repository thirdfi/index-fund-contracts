//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
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

    uint internal constant DENOMINATOR = 10000;
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

    uint public bufferedWithdrawals;
    uint public pendingWithdrawals;
    uint public pendingRedeems;
    uint public emergencyRedeems;

    uint public unbondingPeriod;
    uint public minInvestAmount;
    uint public minRedeemAmount;

    uint public lastInvestTs;
    uint public investInterval;
    uint public lastRedeemTs;
    uint public redeemInterval;

    mapping(address => uint) depositedBlock;
    mapping(uint => WithdrawRequest) nft2WithdrawRequest;

    uint baseApr;
    uint baseTokenRate;
    uint baseAprLastUpdate;

    event Deposit(address user, uint amount, uint shares);
    event Withdraw(address user, uint shares, uint amount, uint reqId, uint pendingAmount);
    event Claim(address user, uint reqId, uint amount);
    event Invest(uint amount);
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
        tokenDecimals = IERC20UpgradeableExt(address(token)).decimals();
        stTokenDecimals = IERC20UpgradeableExt(address(stToken)).decimals();
        oneToken = 10**tokenDecimals;
        oneStToken = 10**stTokenDecimals;

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

    function setStakingPeriods(uint _unbondingPeriod, uint _investInterval, uint _redeemInterval) external onlyOwner {
        unbondingPeriod = _unbondingPeriod;
        investInterval = _investInterval;
        redeemInterval = _redeemInterval;
    }

    function setStakingAmounts(uint _minInvestAmount, uint _minRedeemAmount) external onlyOwner {
        minInvestAmount = _minInvestAmount;
        minRedeemAmount = _minRedeemAmount;
    }

    function deposit(uint _amount) external nonReentrant whenNotPaused{
        require(_amount > 0, "Invalid amount");
        depositedBlock[msg.sender] = block.number;

        uint _shares = getSharesByPool(_amount);
        token.safeTransferFrom(msg.sender, address(this), _amount);

        _mint(msg.sender, _shares);
        adjustWatermark(_amount, true);
        emit Deposit(msg.sender, _amount, _shares);
    }

    function withdraw(uint _shares) external nonReentrant returns (uint _amount, uint _reqId) {
        require(_shares > 0, "Invalid Amount");
        require(balanceOf(msg.sender) >= _shares, "Not enough balance");
        require(depositedBlock[msg.sender] != block.number, "Withdraw within same block");

        uint withdrawAmt = getPoolByShares(_shares);
        _burn(msg.sender, _shares);
        adjustWatermark(withdrawAmt, false);

        uint _buffered = bufferedDeposits();
        if (_buffered >= withdrawAmt) {
            _amount = withdrawAmt;
            withdrawAmt = 0;
        } else {
            _amount = _buffered;
            withdrawAmt -= _buffered;

            uint stTokenAmt = getStTokenByPooledToken(withdrawAmt);
            pendingWithdrawals += withdrawAmt;
            if (paused() == false) {
                pendingRedeems += stTokenAmt;
            } else {
                uint _emergencyRedeems = emergencyRedeems;
                emergencyRedeems = (_emergencyRedeems <= stTokenAmt) ? 0 : _emergencyRedeems - stTokenAmt;
            }

            _reqId = nft.mint(msg.sender);
            nft2WithdrawRequest[_reqId] = WithdrawRequest({
                tokenAmt: withdrawAmt,
                stTokenAmt: stTokenAmt,
                requestTs: block.timestamp
            });
        }

        if (_amount > 0) {
            token.safeTransfer(msg.sender, _amount);
        }
        emit Withdraw(msg.sender, _shares, _amount, _reqId, withdrawAmt);
    }

    function claim(uint _reqId) external nonReentrant returns (uint _amount) {
        require(nft.isApprovedOrOwner(msg.sender, _reqId), "Not owner");
        WithdrawRequest memory usersRequest = nft2WithdrawRequest[_reqId];

        require(block.timestamp >= (usersRequest.requestTs + unbondingPeriod), "Not able to claim yet");

        _amount = usersRequest.tokenAmt;
        require(bufferedWithdrawals >= _amount, "No enough token");

        nft.burn(_reqId);
        token.safeTransfer(msg.sender, _amount);

        pendingWithdrawals -= _amount;
        bufferedWithdrawals -= _amount;
        emit Claim(msg.sender, _reqId, _amount);
    }

    function invest() external onlyOwnerOrAdmin whenNotPaused {
        _investInternal();
    }
    function _investInternal() internal {
        _collectProfitAndUpdateWatermark();
        uint _buffered = _transferOutFees();
        if (_buffered >= minInvestAmount && block.timestamp >= (lastInvestTs + investInterval)) {
            _invest(_buffered);
            lastInvestTs = block.timestamp;
            emit Invest(_buffered);
        }
    }
    function _invest(uint _amount) internal virtual {}

    function redeem() external onlyOwnerOrAdmin whenNotPaused { 
        uint _pendingRedeems = pendingRedeems;
        require(_pendingRedeems >= minRedeemAmount, "No enough pending redeem");
        require(block.timestamp >= (lastRedeemTs + redeemInterval), "Not able to redeem yet");
        _redeem(_pendingRedeems);
        pendingRedeems = 0;
    }
    function _redeem(uint _pendingRedeems) internal virtual {}

    function claimUnbonded() external onlyOwnerOrAdmin {
        _claimUnbonded();
    }
    function _claimUnbonded() internal virtual {}

    ///@notice Withdraws funds staked in mirror to this vault and pauses deposit, yield, invest functions
    function emergencyWithdraw() external onlyOwnerOrAdmin whenNotPaused {
        _pause();
        _yield();
        _emergencyWithdraw(pendingRedeems);
        pendingRedeems = 0;
        emit EmergencyWithdraw(emergencyRedeems);
    }
    function _emergencyWithdraw(uint _pendingRedeems) internal virtual {}

    ///@notice Unpauses deposit, yield, invest functions, and invests funds.
    function reinvest() external onlyOwnerOrAdmin whenPaused {
        _unpause();
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
            fee = profit * yieldFee / DENOMINATOR;
            fees += fee;
            watermark = currentWatermark - fee;
        }
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
        _tokenAmt = token.balanceOf(address(this)) - bufferedWithdrawals;
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

            token.safeTransfer(treasuryWallet, feeAmt);
            emit TransferredOutFees(feeAmt, address(token)); // Decimal follows token
        }
    }

    function bufferedDeposits() public view returns(uint) {
        uint _amount = token.balanceOf(address(this)) - bufferedWithdrawals;
        return (_amount > fees) ? _amount - fees : 0;
    }

    ///@param _amount Amount of tokens
    function getStTokenByPooledToken(uint _amount) public virtual view returns(uint) {
        return Token.changeDecimals(_amount, tokenDecimals, stTokenDecimals);
    }

    ///@param _stAmount Amount of stTokens
    function getPooledTokenByStToken(uint _stAmount) public virtual view returns(uint) {
        return _stAmount * oneToken / getStTokenByPooledToken(oneToken);
    }

    function getAllPool() public virtual view returns (uint _pool) {
        uint stBalance = stToken.balanceOf(address(this)) + emergencyRedeems - pendingRedeems;
        _pool = (stBalance == 0) ? 0 : getPooledTokenByStToken(stBalance);
        _pool += (token.balanceOf(address(this)) - bufferedWithdrawals);
        _pool -= fees;
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
    function getValueInUSD(address _asset, uint _amount) internal view returns(uint) {
        (uint priceInUSD, uint8 priceDecimals) = priceOracle.getAssetPrice(_asset);
        uint8 _decimals = IERC20UpgradeableExt(_asset).decimals();
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

    function getWithdrawRequest(uint _reqId) public view returns (
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
        } else if (bufferedWithdrawals >= _tokenAmt) {
            _claimable = true;
        }
    }

    function getUnbondedToken() public virtual view returns (uint) {
        return 0;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[22] private __gap;
}
