//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../../bni/priceOracle/IPriceOracle.sol";
import "../../../interfaces/IERC20UpgradeableExt.sol";
import "../../../libs/Token.sol";

interface ICToken is IERC20Upgradeable {
    function comptroller() external view returns (address);
    function underlying() external view returns (address);
    function exchangeRateStored() external view returns (uint);
    function supplyRatePerBlock() external view returns (uint);

    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);
}

interface IComptroller {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function exitMarket(address cToken) external returns (uint);
}

contract BasicCompoundVault is Initializable, ERC20Upgradeable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint constant DENOMINATOR = 10000;
    uint public yieldFee;

    ICToken public cToken;
    IERC20Upgradeable public token;
    uint8 private tokenDecimals;
    IComptroller public comptroller;

    address public treasuryWallet;
    address public admin;
    IPriceOracle public priceOracle;

    mapping(address => uint) private depositedBlock;

    uint constant MANTISSA_ONE = 1e18;

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
        ICToken _cToken
    ) public virtual initializer {

        __ERC20_init(_name, _symbol);
        __Ownable_init();

        treasuryWallet = _treasury;
        admin = _admin;
        priceOracle = IPriceOracle(_priceOracle);

        yieldFee = 2000; //20%
        cToken = _cToken;

        token = IERC20Upgradeable(_cToken.underlying());
        tokenDecimals = IERC20UpgradeableExt(address(_cToken)).decimals();
        comptroller = IComptroller(_cToken.comptroller());
        
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(_cToken);
        comptroller.enterMarkets(cTokens);
        token.approve(address(_cToken), type(uint).max);
    }
    
    /**
     *@param _amount amount of lptokens to deposit
    */
    function deposit(uint _amount) external nonReentrant whenNotPaused{
        require(_amount > 0, "Invalid amount");

        uint _pool = getAllPool();
        token.safeTransferFrom(msg.sender, address(this), _amount);

        depositedBlock[msg.sender] = block.number;

        cToken.mint(token.balanceOf(address(this)));

        uint _totalSupply = totalSupply();
        uint _shares = _totalSupply == 0 ? _amount : _amount * _totalSupply / _pool;
        _mint(msg.sender, _shares);

        emit Deposit(msg.sender, _amount, _shares);
    }

    /**
     *@param _shares amount of shares to burn
    */
    function withdraw(uint _shares) external nonReentrant{
        require(_shares > 0, "Invalid Amount");
        require(balanceOf(msg.sender) >= _shares, "Not enough balance");
        require(depositedBlock[msg.sender] != block.number, "Withdraw within same block");

        uint _pool = getAllPool();
        uint _amountToWithdraw = _pool * _shares / totalSupply(); 

        uint available = token.balanceOf(address(this));
        if(available < _amountToWithdraw) {
            cToken.redeem(cToken.balanceOf(address(this)) * (_amountToWithdraw - available) / (_pool - available));
            _amountToWithdraw = token.balanceOf(address(this));
        }
        _burn(msg.sender, _shares);

        token.safeTransfer(msg.sender, _amountToWithdraw);
        emit Withdraw(msg.sender, _amountToWithdraw, _shares);
    }

    function _invest() internal returns (uint available){
        available = token.balanceOf(address(this));
        if(available > 0) {
            cToken.mint(available);
        }
    }

    ///@notice Withdraws funds staked in mirror to this vault and pauses deposit, yield, invest functions
    function emergencyWithdraw() external onlyOwnerOrAdmin whenNotPaused{ 
        _pause();
        _yield();
        uint stakedTokens = cToken.balanceOf(address(this));
        if(stakedTokens > 0 ) {
            cToken.redeem(stakedTokens);
        }
        emit EmergencyWithdraw(stakedTokens);
    }

    ///@notice Unpauses deposit, yield, invest functions, and invests funds.
    function reinvest() external onlyOwnerOrAdmin whenPaused {
        _unpause();
        _invest();
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

    function yield() external onlyOwnerOrAdmin whenNotPaused {
        _yield();
    }

    function _yield() internal virtual {
    }

    function getAllPool() public view returns (uint) {
        uint rate = cToken.exchangeRateStored();
        uint underlyingAmount = (cToken.balanceOf(address(this)) * rate) / MANTISSA_ONE;
        return token.balanceOf(address(this)) + underlyingAmount;
    }

    function getAllPoolInUSD() public view returns (uint) {
        uint _pool = getAllPool();
        return getValueInUSD(address(token), _pool);
    }

    function getPricePerFullShare(bool inUSD) external view returns (uint) {
        uint _totalSupply = totalSupply();
        if (_totalSupply == 0) return 1e18;
        return inUSD == true ?
            getAllPoolInUSD() * 1e18 / _totalSupply :
            getAllPool() * 1e18 / _totalSupply;
    }

    function getValueInUSD(address asset, uint amount) internal view returns(uint) {
        (uint priceInUSD, uint8 priceDecimals) = priceOracle.getAssetPrice(asset);
        uint8 _decimals = IERC20UpgradeableExt(asset).decimals();
        return Token.changeDecimals(amount, _decimals, 18) * priceInUSD / (10 ** (priceDecimals));
    }

    ///@notice Returns the pending rewards in USD.
    function getPendingRewards() public view virtual returns (uint) {
        return 0;
    }

    function getBlocksPerYear() public view virtual returns (uint) {
        return 0;
    }

    ///@dev It's scaled by 1e18
    function getAPR() public view virtual returns (uint) {
        return cToken.supplyRatePerBlock() * getBlocksPerYear();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[41] private __gap;
}
