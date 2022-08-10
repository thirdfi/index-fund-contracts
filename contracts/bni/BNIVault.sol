 // SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./priceOracle/IPriceOracle.sol";
import "../../libs/Const.sol";

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

interface IERC20UpgradeableExt is IERC20Upgradeable {
    function decimals() external view returns (uint8);
}

contract BNIVault is ReentrancyGuardUpgradeable, PausableUpgradeable, OwnableUpgradeable {
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
    mapping(uint => uint) public operationAmounts;

    event Deposit(address caller, uint amtDeposit, address tokenDeposit);
    event Withdraw(address caller, uint amtWithdraw, address tokenWithdraw, uint sharePerc);
    event Rebalance(uint pid, uint sharePerc, uint amount, address target);
    event Reinvest(uint amount);
    event SetTreasuryWallet(address oldTreasuryWallet, address newTreasuryWallet);
    event SetAdminWallet(address oldAdmin, address newAdmin);
    event CollectProfitAndUpdateWatermark(uint currentWatermark, uint lastWatermark, uint fee);
    event AdjustWatermark(uint currentWatermark, uint lastWatermark);
    event TransferredOutFees(uint fees, address token);
    
    modifier onlyOwnerOrAdmin {
        require(msg.sender == owner() || msg.sender == address(admin), "Only owner or admin");
        _;
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

    function getChainID() public view returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }

    /// @notice The length of array is based on token count. And the lengths should be same on the arraies.
    /// @param _USDTAmts amounts of USDT should be deposited to each pools. It's 6 decimals
    function deposit(
        address _account, address[] memory _tokens, uint[] memory _USDTAmts, uint _nonce
    ) external onlyOwnerOrAdmin nonReentrant whenNotPaused {
        require(_account != address(0), "Invalid account");
        uint poolCnt = _tokens.length;
        require(poolCnt == _USDTAmts.length, "Not match array length");

        uint k = 10 ** (usdtDecimals - 6);
        uint USDTAmt;
        for (uint i = 0; i < poolCnt; i ++) {
            _USDTAmts[i] = _USDTAmts[i] * k;
            USDTAmt += _USDTAmts[i];
        }
        require(0 < USDTAmt, "Amounts must > 0");

        require(userLastOperationNonce[_account] < _nonce, "Nonce is behind");
        userLastOperationNonce[_account] = _nonce;
        operationAmounts[_nonce] = USDTAmt;
        _snapshotPool(_nonce, getAllPoolInUSD());

        USDT.safeTransferFrom(_account, address(this), USDTAmt);

        (uint USDTPriceInUSD, uint8 USDTPriceDecimals) = getUSDTPriceInUSD();
        uint amtDeposit = USDTAmt * (10 ** (18-usdtDecimals)) * USDTPriceInUSD / (10 ** USDTPriceDecimals);

        if (watermark > 0) _collectProfitAndUpdateWatermark();
        (uint newUSDTAmt, uint[] memory newUSDTAmts) = _transferOutFees(USDTAmt, _USDTAmts);
        if (newUSDTAmt > 0) {
            strategy.invest(_tokens, newUSDTAmts);
        }
        adjustWatermark(amtDeposit, true);

        emit Deposit(_account, USDTAmt, address(USDT));
    }

    /// @param _sharePerc percentage of assets which should be withdrawn. It's 18 decimals
    function withdrawPerc(
        address _account, uint _sharePerc, uint _nonce
    ) external onlyOwnerOrAdmin nonReentrant {
        require(_sharePerc > 0, "SharePerc must > 0");
        require(_sharePerc <= 1e18, "Over 100%");

        require(userLastOperationNonce[_account] < _nonce, "Nonce is behind");
        userLastOperationNonce[_account] = _nonce;
        operationAmounts[_nonce] = _sharePerc;
        uint pool = getAllPoolInUSD();
        _snapshotPool(_nonce, pool);

        uint withdrawAmt = pool * _sharePerc / 1e18;
        uint sharePerc = withdrawAmt * 1e18 / (pool + fees);
        uint USDTAmt;
        if (!paused()) {
            strategy.withdrawPerc(sharePerc);
            USDTAmt = USDT.balanceOf(address(this));
            adjustWatermark(withdrawAmt, false);
        } else {
            USDTAmt = USDT.balanceOf(address(this)) * sharePerc / 1e18;
        }
        USDT.safeTransfer(_account, USDTAmt);
        emit Withdraw(_account, withdrawAmt, address(USDT), _sharePerc);
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
        address oldTreasuryWallet = treasuryWallet;
        treasuryWallet = _treasuryWallet;
        emit SetTreasuryWallet(oldTreasuryWallet, _treasuryWallet);
    }

    function setAdmin(address _admin) external onlyOwner {
        address oldAdmin = admin;
        admin = _admin;
        emit SetAdminWallet(oldAdmin, _admin);
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

    function getEachPoolInUSD() public view returns (uint[] memory chainIDs, address[] memory tokens, uint[] memory pools) {
        (tokens, pools) = strategy.getEachPoolInUSD();
        uint poolCnt = pools.length;
        uint chainID = getChainID();
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
        if (firstOperationNonce == 0 || _nonce < firstOperationNonce) {
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
        return getAllPoolInUSD();
    }

    function getCurrentCompositionPerc() external view returns (address[] memory tokens, uint[] memory percentages) {
        return strategy.getCurrentTokenCompositionPerc();
    }

    function getAPR() external view returns (uint) {
        return strategy.getAPR();
    }
}
