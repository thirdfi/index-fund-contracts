 // SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../libs/BaseRelayRecipient.sol";

interface IChainlink {
    function latestAnswer() external view returns (int256);
}

interface IStrategy {
    function invest(uint amount) external;
    function withdraw(uint sharePerc) external;
    function withdrawFromFarm(uint farmIndex, uint sharePerc) external returns (uint);
    function emergencyWithdraw() external;
    function getAllPoolInUSD() external view returns (uint);
}

contract LCIVault is ERC20Upgradeable, OwnableUpgradeable, 
        ReentrancyGuardUpgradeable, PausableUpgradeable, BaseRelayRecipient {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant USDT = IERC20Upgradeable(0x55d398326f99059fF775485246999027B3197955);

    IStrategy public strategy;
    address public treasuryWallet;
    address public admin;

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

    function initialize(
        address _treasuryWallet, address _admin,
        address _biconomy, address _strategy
    ) external initializer {
        __ERC20_init("Low-risk Crypto Index", "LCI");
        __Ownable_init();

        strategy = IStrategy(_strategy);

        treasuryWallet = _treasuryWallet;
        admin = _admin;
        trustedForwarder = _biconomy;

        USDT.safeApprove(address(strategy), type(uint).max);
    }

    function deposit(uint amount) external nonReentrant whenNotPaused {
        require(msg.sender == tx.origin || isTrustedForwarder(msg.sender), "Only EOA or Biconomy");
        require(amount > 0, "Amount must > 0");

        address msgSender = _msgSender();
        USDT.safeTransferFrom(msgSender, address(this), amount);

        uint pool = getAllPoolInUSD();
        strategy.invest(amount);

        uint amtDeposit = amount; // USDT's decimals is 18
        uint _totalSupply = totalSupply();
        uint share = _totalSupply == 0 ? amtDeposit : amtDeposit * _totalSupply / pool;
        _mint(msgSender, share);

        emit Deposit(msgSender, amtDeposit, address(USDT), share);
    }

    function withdraw(uint share) external nonReentrant {
        require(msg.sender == tx.origin, "Only EOA");
        require(share > 0, "Shares must > 0");
        require(share <= balanceOf(msg.sender), "Not enough share to withdraw");
        
        uint _totalSupply = totalSupply();
        uint withdrawAmt = getAllPoolInUSD() * share / _totalSupply;

        if (!paused()) {
            strategy.withdraw(share * 1e18 / _totalSupply);
            USDT.safeTransfer(msg.sender, USDT.balanceOf(address(this)));
        } else {
            USDT.safeTransfer(msg.sender, withdrawAmt); // USDT's decimals is 18
        }
        _burn(msg.sender, share);
        emit Withdraw(msg.sender, withdrawAmt, address(USDT), share);
    }

    function rebalance(uint farmIndex, uint sharePerc) external onlyOwnerOrAdmin {
        uint USDTAmt = strategy.withdrawFromFarm(farmIndex, sharePerc);
        strategy.invest(USDTAmt);
        emit Rebalance(farmIndex, sharePerc, USDTAmt);
    }

    function emergencyWithdraw() external onlyOwnerOrAdmin whenNotPaused {
        _pause();
        strategy.emergencyWithdraw();
    }

    function reinvest() external onlyOwnerOrAdmin whenPaused {
        _unpause();
        uint USDTAmt = USDT.balanceOf(address(this));
        strategy.invest(USDTAmt);
        emit Reinvest(USDTAmt);
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
        if (paused()) return USDT.balanceOf(address(this)); // USDT's decimals is 18
        return strategy.getAllPoolInUSD();
    }

    /// @notice Can be use for calculate both user shares & APR    
    function getPricePerFullShare() external view returns (uint) {
        return getAllPoolInUSD() * 1e18 / totalSupply();
    }
}
