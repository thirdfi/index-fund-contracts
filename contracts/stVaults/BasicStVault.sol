//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../bni/priceOracle/IPriceOracle.sol";
import "../../interfaces/IStVault.sol";

contract BasicStVault is IStVault, ERC20Upgradeable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint constant DENOMINATOR = 10000;
    uint public override yieldFee;

    address public override treasuryWallet;
    address public override admin;
    IPriceOracle public priceOracle;

    address public override token;
    address public override stToken;

    bool public override rebaseable;

    uint public override bufferedDeposits;
    uint public override bufferedWithdrawals;
    uint public override pendingRedeems;
    uint public override unbondingRedeems;

    uint public override unbondingPeriod;

    uint public override lastInvestTs;
    uint public override investInterval;
    uint public override lastRedeemTs;
    uint public override redeemInterval;

    mapping(address => uint) private depositedBlock;

    uint constant DAY_IN_SEC = 86400; // 3600 * 24
    uint constant YEAR_IN_SEC = 365 * DAY_IN_SEC;

    event Deposit(address _user, uint _amount, uint _shares);
    event EmergencyWithdraw(uint _amount);
    event Invest(uint _amount);
    event SetAdmin(address _oldAdmin, address _newAdmin);
    event SetYieldFeePerc(uint _fee);
    event SetTreasuryWallet(address _wallet);
    event Withdraw(address _user, uint _amount, uint _shares);

    modifier onlyOwnerOrAdmin {
        require(msg.sender == owner() || msg.sender == admin, "Only owner or admin");
        _;
    }

    function initialize(string memory _name, string memory _symbol, 
        address _treasury, address _admin,
        address _priceOracle,
        address _token, address _stToken
    ) public virtual initializer {

        __ERC20_init(_name, _symbol);
        __Ownable_init();

        yieldFee = 2000; //20%
        treasuryWallet = _treasury;
        admin = _admin;
        priceOracle = IPriceOracle(_priceOracle);

        token = _token;
        stToken = _stToken;
    }

    function setAdmin(address _newAdmin) external onlyOwner{
        address oldAdmin = admin;
        admin = _newAdmin;

        emit SetAdmin(oldAdmin, _newAdmin);
    }

    ///@notice Function to set deposit and yield fee
    ///@param _yieldFeePerc deposit fee percentage. 2000 for 20%
    function setFee(uint _yieldFeePerc) external onlyOwner{
        require(_yieldFeePerc < 3001, "Yield Fee cannot > 30%");
        yieldFee = _yieldFeePerc;
        emit SetYieldFeePerc(_yieldFeePerc);
    }

    function setTreasuryWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0), "wallet invalid");
        treasuryWallet = _wallet;
        emit SetTreasuryWallet(_wallet);
    }

    function deposit(uint _amount) external nonReentrant whenNotPaused{
        // require(_amount > 0, "Invalid amount");

        // uint _pool = getAllPool();
        // token.safeTransferFrom(msg.sender, address(this), _amount);

        // depositedBlock[msg.sender] = block.number;

        // aPool.supply(address(token), token.balanceOf(address(this)), address(this), 0);

        // uint _totalSupply = totalSupply();
        // uint _shares = _totalSupply == 0 ? _amount : _amount * _totalSupply / _pool;
        // _mint(msg.sender, _shares);

        // emit Deposit(msg.sender, _amount, _shares);
    }

    function requestWithdraw(uint _shares) external nonReentrant{
        // require(_shares > 0, "Invalid Amount");
        // require(balanceOf(msg.sender) >= _shares, "Not enough balance");
        // require(depositedBlock[msg.sender] != block.number, "Withdraw within same block");

        // uint _amountToWithdraw = getAllPool() * _shares / totalSupply(); 

        // uint available = token.balanceOf(address(this));
        // if(available < _amountToWithdraw) {
        //     aPool.withdraw(address(token), _amountToWithdraw - available, address(this));
        //     _amountToWithdraw = token.balanceOf(address(this));
        // }
        // _burn(msg.sender, _shares);

        // token.safeTransfer(msg.sender, _amountToWithdraw);
        // emit Withdraw(msg.sender, _amountToWithdraw, _shares);
    }

    // function _invest() internal returns (uint available){
    //     available = token.balanceOf(address(this));
    //     if(available > 0) {
    //         aPool.supply(address(token), available, address(this), 0);
    //     }
    // }

    function invest() external onlyOwnerOrAdmin whenNotPaused{ 
    }

    function redeem() external onlyOwnerOrAdmin whenNotPaused{ 
    }

    function claimUnbonded() external onlyOwnerOrAdmin whenNotPaused{ 
    }

    ///@notice Withdraws funds staked in mirror to this vault and pauses deposit, yield, invest functions
    function emergencyWithdraw() external onlyOwnerOrAdmin whenNotPaused{ 
        _pause();
        // _yield();
        // uint stakedTokens = aToken.balanceOf(address(this));
        // if(stakedTokens > 0 ) {
        //     aPool.withdraw(address(token), stakedTokens, address(this));
        // }
        // emit EmergencyWithdraw(stakedTokens);
    }

    ///@notice Unpauses deposit, yield, invest functions, and invests funds.
    function reinvest() external onlyOwnerOrAdmin whenPaused {
        _unpause();
        // _invest();
    }

    function yield() external onlyOwnerOrAdmin whenNotPaused {
        _yield();
    }

    function _yield() internal virtual {
    }

    function getAllPool() public view returns (uint ) {
        // return token.balanceOf(address(this)) + aToken.balanceOf(address(this));
        return 0;
    }

    function getSharesByPool(uint _amount) public view returns (uint) {
        return 0;
    }

    function getPoolByShares(uint _shares) public view returns (uint) {
        return 0;
    }

    function getAllPoolInUSD() public view returns (uint) {
        // uint _pool = getAllPool();
        // return getValueInUSD(address(token), _pool);
        return 0;
    }

    // function getValueInUSD(address asset, uint amount) internal view returns(uint) {
    //     (uint priceInUSD, uint8 priceDecimals) = priceOracle.getAssetPrice(asset);
    //     uint8 _decimals = IERC20UpgradeableExt(asset).decimals();
    //     return Token.changeDecimals(amount, _decimals, 18) * priceInUSD / (10 ** (priceDecimals));
    // }

    ///@notice Returns the pending rewards in USD.
    function getPendingRewards() public view returns (uint) {
        return 0;
    }

    function getAPR() public view returns (uint) {
        return 0;
    }

    function getUnbondedToken() public view returns (uint) {
        return 0;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[40] private __gap;
}
