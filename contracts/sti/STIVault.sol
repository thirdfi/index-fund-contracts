// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../bni/priceOracle/IPriceOracle.sol";
import "../../interfaces/IERC20UpgradeableExt.sol";
import "../../libs/Const.sol";
import "../../libs/Token.sol";
import "../../libs/BaseRelayRecipient.sol";
import "./ISTIVault.sol";

interface IStrategy {
    function invest(address[] memory tokens, uint[] memory USDTAmts) external;
    function withdrawPerc(address claimer, uint sharePerc) external;
    function claim(address _claimer) external returns (uint USDTAmt);
    function emergencyWithdraw() external;
    function claimEmergencyWithdrawal() external;
    function reinvest(address[] memory tokens, uint[] memory USDTAmts) external;
    function getEmergencyWithdrawalUnbonded() external view returns (uint waitingInUSD, uint unbondedInUSD, uint waitForTs);
    function getPoolsUnbonded(address _claimer) external view returns (
        address[] memory tokens,
        uint[] memory waitings,
        uint[] memory waitingInUSDs,
        uint[] memory unbondeds,
        uint[] memory unbondedInUSDs,
        uint[] memory waitForTses
    );
    function getAllUnbonded(address _claimer) external view returns (uint waitingInUSD, uint unbondedInUSD, uint waitForTs);
    function getPoolCount() external view returns (uint);
    function getEachPoolInUSD() external view returns (address[] memory tokens, uint[] memory pools);
    function getAllPoolInUSD() external view returns (uint);
    function getCurrentTokenCompositionPerc() external view returns (address[] memory tokens, uint[] memory percentages);
    function getAPR() external view returns (uint);
}

contract STIVault is
    ISTIVault,
    BaseRelayRecipient,
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

    uint public firstOperationNonce;
    uint public lastOperationNonce;
    mapping(uint => PoolSnapshot) public poolAtNonce;
    mapping(address => uint) public userLastOperationNonce;
    mapping(uint => uint) public operationAmounts; // value in USD scaled by 10^18

    address public userAgent;

    event Deposit(address indexed account, address from, uint indexed amtDeposit, address indexed tokenDeposit);
    event Withdraw(address indexed account, address to, uint indexed amtWithdraw, address indexed tokenWithdraw, uint sharePerc);
    event Reinvest(uint indexed amount);
    
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
        address _admin, address _userAgent, address _biconomy,
        address _strategy, address _priceOracle,
        address _USDT
    ) external initializer {
        __Ownable_init();
        admin = _admin;
        userAgent = _userAgent;

        trustedForwarder = _biconomy;
        strategy = IStrategy(_strategy);
        priceOracle = IPriceOracle(_priceOracle);

        USDT = IERC20UpgradeableExt(_USDT);
        usdtDecimals = USDT.decimals();
        require(6 <= usdtDecimals, "USDT decimals must >= 6");

        USDT.safeApprove(address(strategy), type(uint).max);
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
        require(USDTAmt > 0, "Amounts must > 0");

        require(userLastOperationNonce[_account] < _nonce, "Nonce is behind");
        userLastOperationNonce[_account] = _nonce;
        operationAmounts[_nonce] = getValueInUSD(address(USDT), USDTAmt);
        _snapshotPool(_nonce, getAllPoolInUSD());

        USDT.safeTransferFrom(_from, address(this), USDTAmt);
        strategy.invest(_tokens, _USDT6Amts);
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

        (uint vaultPool, uint strategyPool) = _getAllPoolInUSD();
        uint pool = vaultPool + strategyPool;
        uint withdrawAmt = pool * _sharePerc / 1e18;

        require(userLastOperationNonce[_account] < _nonce, "Nonce is behind");
        userLastOperationNonce[_account] = _nonce;
        operationAmounts[_nonce] = withdrawAmt;
        _snapshotPool(_nonce, pool);

        uint USDTAmt;
        if (withdrawAmt <= vaultPool) {
            USDTAmt = USDT.balanceOf(address(this)) * withdrawAmt / vaultPool;
        } else {
            if (paused() == false) {
                strategy.withdrawPerc(_account, 1e18 * (withdrawAmt - vaultPool) / strategyPool);
                USDTAmt = USDT.balanceOf(address(this));
            } else {
                require(false, "Retry after all claimed");
            }
        }

        if (USDTAmt > 0) {
            USDT.safeTransfer(_to, USDTAmt);
        }
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

    function claim() external nonReentrant {
        _claimAllAndTransfer(msg.sender, msg.sender);
    }

    function claimByAdmin(address _account) external onlyOwnerOrAdmin nonReentrant {
        _claimAllAndTransfer(_account, _account);
    }

    function claimByAgent(address _account) external onlyAgent nonReentrant {
        _claimAllAndTransfer(_account, _msgSender());
    }

    function _claimAllAndTransfer(address _account, address _to) internal {
        uint USDTAmt = strategy.claim(_account);
        if (USDTAmt > 0) {
            USDT.safeTransfer(_to, USDTAmt);
        }
    }

    function emergencyWithdraw() external onlyOwnerOrAdmin whenNotPaused {
        _pause();
        strategy.emergencyWithdraw();
    }

    function claimEmergencyWithdrawal() external onlyOwnerOrAdmin whenPaused {
        strategy.claimEmergencyWithdrawal();
    }

    function reinvest(address[] memory _tokens, uint[] memory _perc) external onlyOwnerOrAdmin whenPaused {
        uint poolCnt = _tokens.length;
        require(poolCnt == _perc.length, "Not match array length");

        (uint waitingInUSD, uint unbondedInUSD,) = getEmergencyWithdrawalUnbonded();
        require(waitingInUSD + unbondedInUSD == 0, "Need to claim emergency withdrawal first");

        _unpause();
        uint USDTAmt = USDT.balanceOf(address(this));
        if (USDTAmt > 0) {
            uint totalPerc;
            for (uint i = 0; i < poolCnt; i ++) {
                totalPerc += _perc[i];
            }

            uint[] memory USMTAmts = new uint[](poolCnt);
            for (uint i = 0; i < poolCnt; i ++) {
                USMTAmts[i] = _perc[i] * USDTAmt / totalPerc;
            }

            strategy.reinvest(_tokens, USMTAmts);
            emit Reinvest(USDTAmt);
        }
    }

    function setStrategy(address _strategy) external onlyOwner {
        strategy = IStrategy(_strategy);

        if (USDT.allowance(address(this), address(strategy)) == 0) {
            USDT.safeApprove(address(strategy), type(uint).max);
        }
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

    function _msgSender() internal override(ContextUpgradeable, BaseRelayRecipient) view returns (address) {
        return BaseRelayRecipient._msgSender();
    }

    function versionRecipient() external pure override returns (string memory) {
        return "1";
    }

    function getPoolsUnbonded(address _account) external view returns (
        uint[] memory chainIDs,
        address[] memory tokens,
        uint[] memory waitings,
        uint[] memory waitingInUSDs,
        uint[] memory unbondeds,
        uint[] memory unbondedInUSDs,
        uint[] memory waitForTses
    ) {
        (tokens, waitings, waitingInUSDs, unbondeds, unbondedInUSDs, waitForTses) = strategy.getPoolsUnbonded(_account);

        uint poolCnt = tokens.length;
        uint chainID = Token.getChainID();
        chainIDs = new uint[](poolCnt);
        for (uint _pid = 0; _pid < poolCnt; _pid ++) {
            chainIDs[_pid] = chainID;
        }
    }

    function getAllUnbonded(address _account) external view returns (
        uint waitingInUSD, uint unbondedInUSD, uint waitForTs
    ) {
        return strategy.getAllUnbonded(_account);
    }

    function getEmergencyWithdrawalUnbonded() public view returns (
        uint waitingInUSD, uint unbondedInUSD, uint waitForTs
    ) {
        return strategy.getEmergencyWithdrawalUnbonded();
    }

    ///@return chainID is the ID of the current chain
    ///@return sharePerc is percentage of the value in the vault of the total value. It's useful for calculating the withdrawable share under emergency status.
    function getWithdrawableSharePerc() public view returns (uint chainID, uint sharePerc) {
        chainID = Token.getChainID();
        if (paused() == false) {
            sharePerc = 1e18;
        } else {
            // In emergency mode, the unclaimed assets can not be withdrawn.
            (uint vaultPool, uint strategyPool) = _getAllPoolInUSD();
            sharePerc = 1e18 * vaultPool / (vaultPool + strategyPool);
        }
    }

    ///@return the price of USDT in USD.
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
            pools[0] += getValueInUSD(address(USDT), USDTAmt);
        }
        return (chainIDs, tokens, pools);
    }

    function getAllPoolInUSD() public view returns (uint allPool) {
        (uint vaultPool, uint strategyPool) = _getAllPoolInUSD();
        allPool = vaultPool + strategyPool;
    }

    function _getAllPoolInUSD() internal view returns (uint vaultPool, uint strategyPool) {
        uint USDTAmt = USDT.balanceOf(address(this));
        if (USDTAmt > 0) {
            vaultPool = getValueInUSD(address(USDT), USDTAmt);
        }
        strategyPool = strategy.getAllPoolInUSD();
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
