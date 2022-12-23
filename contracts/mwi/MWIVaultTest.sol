 // SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../libs/BaseRelayRecipient.sol";
import "./libs/Price.sol";

interface IStrategy {
    function invest(uint amount) external;
    function withdrawPerc(uint sharePerc) external;
    function withdrawFromFarm(uint farmIndex, uint sharePerc) external returns (uint);
    function emergencyWithdraw() external;
    function getAllPoolInUSD() external view returns (uint);
    function getCurrentTokenCompositionPerc() external view returns (address[] memory tokens, uint[] memory percentages);
    function getAPR() external view returns (uint);
}

contract MWIVaultTest is ERC20Upgradeable, OwnableUpgradeable, 
        ReentrancyGuardUpgradeable, PausableUpgradeable, BaseRelayRecipient {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant USDT = IERC20Upgradeable(0x78ae2880bd1672b49a33cF796CF53FE6db0aB01D);

    IStrategy public strategy;
    address public treasuryWallet;
    address public admin;

    mapping(address => uint) private depositedBlock;

    event Deposit(address caller, uint amtDeposit, address tokenDeposit, uint shareMinted);
    event Withdraw(address caller, uint amtWithdraw, address tokenWithdraw, uint shareBurned);
    event Rebalance(uint farmIndex, uint sharePerc, uint amount);
    event Reinvest(uint amount);
    event SetTreasuryWallet(address oldTreasuryWallet, address newTreasuryWallet);
    event SetAdminWallet(address oldAdmin, address newAdmin);
    event SetBiconomy(address oldBiconomy, address newBiconomy);
    
    modifier onlyOwnerOrAdmin {
        require(msg.sender == owner() || msg.sender == address(admin), "Only owner or admin");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _treasuryWallet, address _admin,
        address _biconomy, address _strategy
    ) external initializer {
        __ERC20_init("Market Weighted Index", "MWI");
        __Ownable_init();

        strategy = IStrategy(_strategy);

        treasuryWallet = _treasuryWallet;
        admin = _admin;
        trustedForwarder = _biconomy;

        USDT.safeApprove(address(strategy), type(uint).max);
    }

    function deposit(uint amount) external {
        _deposit(_msgSender(), amount);
    }
    function depositByAdmin(address account, uint amount) external onlyOwnerOrAdmin {
        _deposit(account, amount);
    }
    function _deposit(address account, uint amount) private nonReentrant whenNotPaused {
        require(amount > 0, "Amount must > 0");
        depositedBlock[account] = block.number;

        uint pool = getAllPoolInUSD();
        USDT.safeTransferFrom(account, address(this), amount);

        strategy.invest(amount);

        uint amtDeposit = amount * 1e12;//PriceLib.getAssetPrice(address(USDT)) * 1e4; // USDT's decimals is 6, price's decimals is 8
        uint _totalSupply = totalSupply();
        uint share = (_totalSupply == 0 || pool <= _totalSupply)  ? amtDeposit : amtDeposit * _totalSupply / pool;
        _mint(account, share);

        emit Deposit(account, amtDeposit, address(USDT), share);
    }

    function withdraw(uint share) external {
        _withdraw(_msgSender(), share);
    }
    function withdrawByAdmin(address account, uint share) external onlyOwnerOrAdmin {
        _withdraw(account, share);
    }
    function _withdraw(address account, uint share) private nonReentrant {
        require(share > 0, "Shares must > 0");
        require(share <= balanceOf(account), "Not enough share to withdraw");
        require(depositedBlock[account] != block.number, "Withdraw within same block");
        
        uint _totalSupply = totalSupply();
        uint withdrawAmt = getAllPoolInUSD() * share / _totalSupply;

        if (!paused()) {
            strategy.withdrawPerc(share * 1e18 / _totalSupply);
            USDT.safeTransfer(account, USDT.balanceOf(address(this)));
        } else {
            uint USDTAmt = withdrawAmt / 1e12;//(PriceLib.getAssetPrice(address(USDT)) * 1e4); // USDT's decimals is 6, price's decimals is 8
            USDT.safeTransfer(account, USDTAmt);
        }
        _burn(account, share);
        emit Withdraw(account, withdrawAmt, address(USDT), share);
    }

    function rebalance(uint farmIndex, uint sharePerc) external onlyOwnerOrAdmin {
        uint USDTAmt = strategy.withdrawFromFarm(farmIndex, sharePerc);
        if (0 < USDTAmt) {
            strategy.invest(USDTAmt);
            emit Rebalance(farmIndex, sharePerc, USDTAmt);
        }
    }

    function emergencyWithdraw() external onlyOwnerOrAdmin whenNotPaused {
        _pause();
        strategy.emergencyWithdraw();
    }

    function reinvest() external onlyOwnerOrAdmin whenPaused {
        _unpause();
        uint USDTAmt = USDT.balanceOf(address(this));
        if (0 < USDTAmt) {
            strategy.invest(USDTAmt);
            emit Reinvest(USDTAmt);
        }
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
        address oldBiconomy = trustedForwarder;
        trustedForwarder = _biconomy;
        emit SetBiconomy(oldBiconomy, _biconomy);
    }

    function _msgSender() internal override(ContextUpgradeable, BaseRelayRecipient) view returns (address) {
        return BaseRelayRecipient._msgSender();
    }
    
    function versionRecipient() external pure override returns (string memory) {
        return "1";
    }

    function getAllPoolInUSD() public view returns (uint) {
        if (paused()) return USDT.balanceOf(address(this)) * 1e12;//PriceLib.getAssetPrice(address(USDT)) * 1e4; // USDT's decimals is 6, price's decimals is 8
        return strategy.getAllPoolInUSD();
    }

    /// @notice Can be use for calculate both user shares & APR    
    function getPricePerFullShare() external view returns (uint) {
        uint _totalSupply = totalSupply();
        if (_totalSupply == 0) return 1e18;
        return getAllPoolInUSD() * 1e18 / _totalSupply;
    }

    function getCurrentCompositionPerc() external view returns (address[] memory tokens, uint[] memory percentages) {
        return strategy.getCurrentTokenCompositionPerc();
    }

    function getAPR() external view returns (uint) {
        return strategy.getAPR();
    }
}
