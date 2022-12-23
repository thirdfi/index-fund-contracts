 // SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./priceOracle/IPriceOracle.sol";
import "../../interfaces/IERC20UpgradeableExt.sol";
import "../../libs/Const.sol";
import "../../libs/Token.sol";
import "./IBNIVault.sol";

interface IStrategy {
    function invest(address[] memory tokens, uint[] memory USDTAmts) external;
    function withdrawPerc(uint sharePerc) external;
    function withdrawFromPool(uint pid, uint sharePerc) external returns (uint);
    function emergencyWithdraw() external;
    function getEachPoolInUSD() external view returns (address[] memory tokens, uint[] memory pools);
    function getAllPoolInUSD() external view returns (uint);
    function getCurrentTokenCompositionPerc() external view returns (address[] memory tokens, uint[] memory percentages);
    function getAPR() external view returns (uint);
}

contract BNIVault is
    IBNIVault,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20Upgradeable for IERC20UpgradeableExt;

    struct PoolSnapshot {
        uint poolInUSD;
        uint ts;
    }

    IERC20UpgradeableExt public USDT;
    uint8 usdtDecimals;

    address public admin;
    IStrategy public strategy;
    IPriceOracle public priceOracle;

    uint public profitFeePerc;
    address public treasuryWallet;
    uint public watermark; // In USD (18 decimals)
    uint public fees; // In USD (18 decimals)

    address public trustedForwarder;

    uint public firstOperationNonce;
    uint public lastOperationNonce;
    mapping(uint => PoolSnapshot) public poolAtNonce;
    mapping(address => uint) public userLastOperationNonce;
    mapping(uint => uint) public operationAmounts; // value in USD scaled by 10^18

    uint public version;
    address public userAgent;

    event Deposit(address indexed account, address from, uint indexed amtDeposit, address indexed tokenDeposit);
    event Withdraw(address indexed account, address to, uint indexed amtWithdraw, address indexed tokenWithdraw, uint sharePerc);
    event Rebalance(uint indexed pid, uint sharePerc, uint indexed amount, address indexed target);
    event Reinvest(uint indexed amount);
    event CollectProfitAndUpdateWatermark(uint indexed currentWatermark, uint indexed lastWatermark, uint indexed fee);
    event AdjustWatermark(uint indexed currentWatermark, uint indexed lastWatermark);
    event TransferredOutFees(uint indexed fees, address indexed token);
    
    modifier onlyOwnerOrAdmin {
        require(msg.sender == owner() || msg.sender == address(admin), "Only owner or admin");
        _;
    }

    modifier onlyAgent {
        require(msg.sender == address(userAgent), "Only agent");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _treasuryWallet, address _admin,
        address _strategy, address _priceOracle,
        address _USDT
    ) external initializer {
        __Ownable_init();

        treasuryWallet = _treasuryWallet;
        admin = _admin;
        strategy = IStrategy(_strategy);
        priceOracle = IPriceOracle(_priceOracle);

        profitFeePerc = 2000;

        USDT = IERC20UpgradeableExt(_USDT);
        usdtDecimals = USDT.decimals();
        require(6 <= usdtDecimals, "USDT decimals must >= 6");

        USDT.safeApprove(address(strategy), type(uint).max);
    }

    function initialize2(address _userAgent, address _biconomy) external onlyOwner {
        require(version < 2, "Already called");
        version = 2;

        userAgent = _userAgent;
        trustedForwarder = _biconomy;
    }

    /// @notice The length of array is based on token count. And the lengths should be same on the arraies.
    /// @param _USDT6Amts amounts of USDT should be deposited to each pools. It's 6 decimals
    function depositByAdmin(
        address _account, address[] memory _tokens, uint[] memory _USDT6Amts, uint _nonce
    ) external onlyOwnerOrAdmin nonReentrant whenNotPaused {
        _deposit(_account, _account, _tokens, _USDT6Amts, _nonce);
    }

    function depositByAgent(
        address _account, address[] memory _tokens, uint[] memory _USDT6Amts, uint _nonce
    ) external onlyAgent nonReentrant whenNotPaused {
        _deposit(_account, _msgSender(), _tokens, _USDT6Amts, _nonce);
    }

    function _deposit(
        address _account, address _from, address[] memory _tokens, uint[] memory _USDT6Amts, uint _nonce
    ) private {
        require(_account != address(0), "Invalid account");
        uint poolCnt = _tokens.length;
        require(poolCnt == _USDT6Amts.length, "Not match array length");

        uint k = 10 ** (usdtDecimals - 6);
        uint USDTAmt;
        for (uint i = 0; i < poolCnt; i ++) {
            _USDT6Amts[i] = _USDT6Amts[i] * k;
            USDTAmt += _USDT6Amts[i];
        }
        require(0 < USDTAmt, "Amounts must > 0");

        require(userLastOperationNonce[_account] < _nonce, "Nonce is behind");
        userLastOperationNonce[_account] = _nonce;
        operationAmounts[_nonce] = getValueInUSD(address(USDT), USDTAmt);
        _snapshotPool(_nonce, getAllPoolInUSD());

        USDT.safeTransferFrom(_from, address(this), USDTAmt);

        (uint USDTPriceInUSD, uint8 USDTPriceDecimals) = getUSDTPriceInUSD();
        uint amtDeposit = USDTAmt * (10 ** (18-usdtDecimals)) * USDTPriceInUSD / (10 ** USDTPriceDecimals);

        if (watermark > 0) _collectProfitAndUpdateWatermark();
        (uint newUSDTAmt, uint[] memory newUSDTAmts) = _transferOutFees(USDTAmt, _USDT6Amts);
        if (newUSDTAmt > 0) {
            strategy.invest(_tokens, newUSDTAmts);
        }
        adjustWatermark(amtDeposit, true);

        emit Deposit(_account, _from, USDTAmt, address(USDT));
    }

    /// @param _sharePerc percentage of assets which should be withdrawn. It's 18 decimals
    function withdrawPercByAdmin(
        address _account, uint _sharePerc, uint _nonce
    ) external onlyOwnerOrAdmin nonReentrant {
        _withdraw(_account, _account, _sharePerc, _nonce);
    }

    function withdrawPercByAgent(
        address _account, uint _sharePerc, uint _nonce
    ) external onlyAgent nonReentrant {
        _withdraw(_account, _msgSender(), _sharePerc, _nonce);
    }

    function _withdraw(
        address _account, address _to, uint _sharePerc, uint _nonce
    ) private {
        require(_sharePerc > 0, "SharePerc must > 0");
        require(_sharePerc <= 1e18, "Over 100%");

        uint pool = getAllPoolInUSD();
        uint withdrawAmt = pool * _sharePerc / 1e18;

        require(userLastOperationNonce[_account] < _nonce, "Nonce is behind");
        userLastOperationNonce[_account] = _nonce;
        operationAmounts[_nonce] = withdrawAmt;
        _snapshotPool(_nonce, pool);

        // calculate sharePerc to withdraw from strategy
        uint sharePerc = withdrawAmt * 1e18 / (pool + fees);
        uint USDTAmt;
        if (!paused()) {
            strategy.withdrawPerc(sharePerc);
            USDTAmt = USDT.balanceOf(address(this));
            adjustWatermark(withdrawAmt, false);
        } else {
            USDTAmt = USDT.balanceOf(address(this)) * sharePerc / 1e18;
        }
        USDT.safeTransfer(_to, USDTAmt);
        emit Withdraw(_account, _to, withdrawAmt, address(USDT), _sharePerc);
    }

    function _snapshotPool(uint _nonce, uint _pool) internal {
        poolAtNonce[_nonce] = PoolSnapshot({
            poolInUSD: _pool,
            ts: block.timestamp
        });

        if (firstOperationNonce == 0) {
            firstOperationNonce = _nonce;
        }
        if (lastOperationNonce < _nonce) {
            lastOperationNonce = _nonce;
        }
    }

    function rebalance(uint _pid, uint _sharePerc, address _target) external onlyOwnerOrAdmin {
        uint USDTAmt = strategy.withdrawFromPool(_pid, _sharePerc);
        if (0 < USDTAmt) {
            address[] memory targets = new address[](1);
            targets[0] = _target;
            uint[] memory USDTAmts = new uint[](1);
            USDTAmts[0] = USDTAmt;
            strategy.invest(targets, USDTAmts);
            emit Rebalance(_pid, _sharePerc, USDTAmt, _target);
        }
    }

    function emergencyWithdraw() external onlyOwnerOrAdmin whenNotPaused {
        _pause();
        strategy.emergencyWithdraw();
        watermark = 0;
    }

    function reinvest(address[] memory _tokens, uint[] memory _perc) external onlyOwnerOrAdmin whenPaused {
        uint poolCnt = _tokens.length;
        require(poolCnt == _perc.length, "Not match array length");

        _unpause();
        uint USDTAmt = USDT.balanceOf(address(this));
        if (0 < USDTAmt) {
            (uint USDTPriceInUSD, uint8 USDTPriceDecimals) = getUSDTPriceInUSD();
            uint amtDeposit = USDTAmt * (10 ** (18-usdtDecimals)) * USDTPriceInUSD / (10 ** USDTPriceDecimals);
            uint totalPerc;
            for (uint i = 0; i < poolCnt; i ++) {
                totalPerc = _perc[i];
            }

            uint[] memory USMTAmts = new uint[](poolCnt);
            for (uint i = 0; i < poolCnt; i ++) {
                USMTAmts[i] = _perc[i] * USDTAmt / totalPerc;
            }

            strategy.invest(_tokens, USMTAmts);
            adjustWatermark(amtDeposit, true);
            emit Reinvest(USDTAmt);
        }
    }

    function collectProfitAndUpdateWatermark() external onlyOwnerOrAdmin whenNotPaused {
        _collectProfitAndUpdateWatermark();
    }
    function _collectProfitAndUpdateWatermark() private {
        uint currentWatermark = strategy.getAllPoolInUSD();
        uint lastWatermark = watermark;
        uint fee;
        if (currentWatermark > lastWatermark) {
            uint profit = currentWatermark - lastWatermark;
            fee = profit * profitFeePerc / Const.DENOMINATOR;
            fees += fee;
            watermark = currentWatermark;
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
        if (!paused()) {
            uint pool = strategy.getAllPoolInUSD();
            uint _fees = fees;
            uint sharePerc = _fees < pool ? _fees * 1e18 / pool : 1e18;
            strategy.withdrawPerc(sharePerc);
        }
        _transferOutFees(USDT.balanceOf(address(this)), new uint[](0));
    }

    function _transferOutFees(uint _USDTAmt, uint[] memory _USDTAmts) private returns (uint, uint[] memory) {
        uint _fees = fees;
        if (_fees != 0) {
            (uint USDTPriceInUSD, uint8 USDTPriceDecimals) = getUSDTPriceInUSD();
            uint FeeAmt = _fees * (10 ** USDTPriceDecimals) / ((10 ** (18-usdtDecimals)) * USDTPriceInUSD);

            uint prevUSDTAmt = _USDTAmt;
            uint poolCnt = _USDTAmts.length;
            if (FeeAmt < _USDTAmt) {
                _fees = 0;
                _USDTAmt -= FeeAmt;
            } else {
                _fees -= (_USDTAmt * (10 ** (18-usdtDecimals)) * USDTPriceInUSD / (10 ** USDTPriceDecimals));
                FeeAmt = _USDTAmt;
                _USDTAmt = 0;
            }
            fees = _fees;

            for (uint i = 0; i < poolCnt; i ++) {
                _USDTAmts[i] = _USDTAmts[i] * _USDTAmt / prevUSDTAmt;
            }

            USDT.safeTransfer(treasuryWallet, FeeAmt);
            emit TransferredOutFees(FeeAmt, address(USDT)); // Decimal follow _token
        }
        return (_USDTAmt, _USDTAmts);
    }

    function setStrategy(address _strategy) external onlyOwner {
        strategy = IStrategy(_strategy);

        if (USDT.allowance(address(this), address(strategy)) == 0) {
            USDT.safeApprove(address(strategy), type(uint).max);
        }
    }

    function setProfitFeePerc(uint _profitFeePerc) external onlyOwner {
        require(profitFeePerc < 3001, "Profit fee cannot > 30%");
        profitFeePerc = _profitFeePerc;
    }

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
        treasuryWallet = _treasuryWallet;
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    function setUserAgent(address _userAgent) external onlyOwner {
        userAgent = _userAgent;
    }

    function setBiconomy(address _biconomy) external onlyOwner {
        trustedForwarder = _biconomy;
    }

    function isTrustedForwarder(address forwarder) public view returns(bool) {
        return forwarder == trustedForwarder;
    }

    function _msgSender() internal override(ContextUpgradeable) view returns (address ret) {
        if (msg.data.length >= 24 && isTrustedForwarder(msg.sender)) {
            // At this point we know that the sender is a trusted forwarder,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            assembly {
                ret := shr(96,calldataload(sub(calldatasize(),20)))
            }
        } else {
            return msg.sender;
        }
    }

    function versionRecipient() external pure returns (string memory) {
        return "1";
    }

    /// @return the price of USDT in USD.
    function getUSDTPriceInUSD() public view returns(uint, uint8) {
        return priceOracle.getAssetPrice(address(USDT));
    }

    ///@return the value in USD. it's scaled by 1e18;
    function getValueInUSD(address _asset, uint _amount) internal view returns (uint) {
        (uint priceInUSD, uint8 priceDecimals) = priceOracle.getAssetPrice(_asset);
        uint8 _decimals = IERC20UpgradeableExt(_asset).decimals();
        return Token.changeDecimals(_amount, _decimals, 18) * priceInUSD / (10 ** (priceDecimals));
    }

    function getEachPoolInUSD() public view returns (uint[] memory chainIDs, address[] memory tokens, uint[] memory pools) {
        (tokens, pools) = strategy.getEachPoolInUSD();
        uint poolCnt = pools.length;
        uint chainID = Token.getChainID();
        chainIDs = new uint[](poolCnt);
        for (uint i = 0; i < poolCnt; i ++) {
            chainIDs[i] = chainID;
        }

        uint USDTAmt = USDT.balanceOf(address(this));
        if(USDTAmt > 0 && poolCnt > 0) {
            (uint USDTPriceInUSD, uint8 USDTPriceDecimals) = getUSDTPriceInUSD();
            uint _pool = USDT.balanceOf(address(this)) * (10 ** (18-usdtDecimals)) * USDTPriceInUSD / (10 ** USDTPriceDecimals);
            pools[0] += _pool;
        }
        return (chainIDs, tokens, pools);
    }

    function getAllPoolInUSD() public view returns (uint) {
        uint pool;
        if (paused()) {
            (uint USDTPriceInUSD, uint8 USDTPriceDecimals) = getUSDTPriceInUSD();
            pool = USDT.balanceOf(address(this)) * (10 ** (18-usdtDecimals)) * USDTPriceInUSD / (10 ** USDTPriceDecimals);
        } else {
            pool = strategy.getAllPoolInUSD();
        }
        return (pool > fees ? pool - fees : 0);
    }

    function getAllPoolInUSDAtNonce(uint _nonce) public view returns (uint) {
        if (firstOperationNonce != 0) {
            if (_nonce < firstOperationNonce) {
                return 0;
            }
            if (_nonce <= lastOperationNonce) {
                for (uint i = _nonce; i >= firstOperationNonce; i --) {
                    PoolSnapshot memory snapshot = poolAtNonce[i];
                    if (snapshot.ts > 0) {
                        return snapshot.poolInUSD;
                    }
                }
            }
        }
        return getAllPoolInUSD();
    }

    function getCurrentCompositionPerc() external view returns (address[] memory tokens, uint[] memory percentages) {
        return strategy.getCurrentTokenCompositionPerc();
    }

    function getAPR() external view returns (uint) {
        return strategy.getAPR();
    }
}
