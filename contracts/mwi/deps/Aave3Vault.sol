//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../libs/DataTypes.sol";
import "../libs/Price.sol";

interface IUniRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity) ;

    function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);

}

interface IERC20UpgradeableEx is IERC20Upgradeable {
    function decimals() external view returns (uint8);
}

interface IAToken is IERC20Upgradeable {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
    function POOL() external view returns (address);
    function getIncentivesController() external view returns (address);
}

interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to ) external returns (uint256);
    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);
}

interface IRewardsController {
    /// @dev asset The incentivized asset. It should be address of AToken
    function getRewardsByAsset(address asset) external view returns (address[] memory);
    function getRewardsData(address asset, address reward) external view returns (
      uint256 index,
      uint256 emissionPerSecond,
      uint256 lastUpdateTimestamp,
      uint256 distributionEnd
    );
    function getAllUserRewards(address[] calldata assets, address user) external view returns (address[] memory, uint256[] memory);
    function getUserRewards(address[] calldata assets, address user, address reward) external view returns (uint256);
    function claimAllRewards(address[] calldata assets, address to) external returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
    function claimAllRewardsToSelf(address[] calldata assets) external returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
}

contract Aave3Vault is Initializable, ERC20Upgradeable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant WAVAX = IERC20Upgradeable(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);

    IUniRouter public constant JoeRouter = IUniRouter(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);

    uint constant DENOMINATOR = 10000;
    uint public yieldFee;

    IAToken public aToken;
    IERC20Upgradeable public token;
    uint8 private tokenDecimals;
    IPool public aPool;
    IRewardsController public aRewardsController;

    address public treasuryWallet;
    address public admin;

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
    event YieldFee(uint _amount);
    event Yield(uint _amount);

    modifier onlyOwnerOrAdmin {
        require(msg.sender == owner() || msg.sender == admin, "Only owner or admin");
        _;
    }

    function initialize(string memory _name, string memory _symbol, 
        IAToken _aToken,
        address _treasury, address _admin
    ) external initializer {

        __ERC20_init(_name, _symbol);
        __Ownable_init();

        yieldFee = 2000; //20%
        aToken = _aToken;

        token = IERC20Upgradeable(aToken.UNDERLYING_ASSET_ADDRESS());
        tokenDecimals = IERC20UpgradeableEx(address(token)).decimals();
        aPool = IPool(aToken.POOL());
        aRewardsController = IRewardsController(aToken.getIncentivesController());
        
        treasuryWallet = _treasury;
        admin = _admin;
        
        token.approve(address(aPool), type(uint).max);
        aToken.approve(address(aPool), type(uint).max);
        WAVAX.approve(address(JoeRouter), type(uint).max);
    }
    
    /**
     *@param _amount amount of lptokens to deposit
    */
    function deposit(uint _amount) external nonReentrant whenNotPaused{
        require(_amount > 0, "Invalid amount");

        uint _pool = getAllPool();
        token.safeTransferFrom(msg.sender, address(this), _amount);

        depositedBlock[msg.sender] = block.number;

        aPool.supply(address(token), token.balanceOf(address(this)), address(this), 0);

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

        uint _amountToWithdraw = getAllPool() * _shares / totalSupply(); 

        uint available = token.balanceOf(address(this));
        if(available < _amountToWithdraw) {
            aPool.withdraw(address(token), _amountToWithdraw - available, address(this));
        }
        _burn(msg.sender, _shares);

        token.safeTransfer(msg.sender, _amountToWithdraw);
        emit Withdraw(msg.sender, _amountToWithdraw, _shares);
    }

    function _invest() private returns (uint available){
        available = token.balanceOf(address(this));
        if(available > 0) {
            aPool.supply(address(token), available, address(this), 0);
        }
    }

    ///@notice Withdraws funds staked in mirror to this vault and pauses deposit, yield, invest functions
    function emergencyWithdraw() external onlyOwnerOrAdmin whenNotPaused{ 
        _pause();
        _yield();
        uint stakedTokens = aToken.balanceOf(address(this));
        if(stakedTokens > 0 ) {
            aPool.withdraw(address(token), stakedTokens, address(this));
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

    function _yield() private {
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);
        (address[] memory rewards, uint[] memory amounts) = aRewardsController.claimAllRewardsToSelf(assets);

        uint rewardsCount = rewards.length;
        for (uint i = 0; i < rewardsCount; i ++) {
            address reward = rewards[i];
            uint amount = amounts[i];
            if (0 < amount && reward != address(WAVAX)) {
                IERC20Upgradeable(reward).safeTransfer(treasuryWallet, amount);
            }
        }

        uint AVAXAmt = WAVAX.balanceOf(address(this));
        if(AVAXAmt > 0) {
            uint fee = AVAXAmt * yieldFee / DENOMINATOR; //yield fee
            WAVAX.safeTransfer(treasuryWallet, fee);
            AVAXAmt -= fee;

            if (token != WAVAX) {
                _swap(address(WAVAX), address(token), AVAXAmt);
            }
            _invest();

            uint AVAXPriceInUSD = PriceLib.getAssetPrice(address(WAVAX));
            emit Yield((AVAXAmt + fee) * AVAXPriceInUSD / 1e8);
            emit YieldFee(fee * AVAXPriceInUSD / 1e8);
        }
    }

    function _swap(address _tokenA, address _tokenB, uint _amt) private returns (uint[] memory amounts){
        address[] memory path = new address[](2);

        path[0] = address(_tokenA);
        path[1] = address(_tokenB);

        amounts = JoeRouter.swapExactTokensForTokens(_amt, 0, path, address(this), block.timestamp);
    }

    function getAllPool() public view returns (uint ) {
        return token.balanceOf(address(this)) + aToken.balanceOf(address(this));
    }

    function getAllPoolInUSD() public view returns (uint) {
        uint priceInUSD = PriceLib.getAssetPrice(address(token));
        uint _pool = getAllPool();
        if (tokenDecimals < 18) {
            _pool = _pool * (10 ** (18-tokenDecimals));
        }
        return _pool * priceInUSD / 1e8;
    }

    function getPricePerFullShare(bool inUSD) external view returns (uint) {
        uint _totalSupply = totalSupply();
        if (_totalSupply == 0) return 1e18;
        return inUSD == true ?
            getAllPoolInUSD() * 1e18 / _totalSupply :
            getAllPool() * 1e18 / _totalSupply;
    }

    ///@notice Returns the pending rewards in USD.
    function getPendingRewards() public view returns (uint) {
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);
        (address[] memory rewards, uint[] memory amounts) = aRewardsController.getAllUserRewards(assets, address(this));

        uint rewardsCount = rewards.length;
        uint pending;
        for (uint i = 0; i < rewardsCount; i ++) {
            address reward = rewards[i];
            uint priceInUSD = PriceLib.getAssetPrice(address(reward));
            uint numeratorDecimals = 18; // USD precision
            uint denominatorDecimals = IERC20UpgradeableEx(address(reward)).decimals() // against to amounts
                                    + 8; // against to priceInUSD
            uint _pending = (numeratorDecimals < denominatorDecimals)
                            ? amounts[i] * priceInUSD / (10 ** (denominatorDecimals-numeratorDecimals))
                            : amounts[i] * priceInUSD * (10 ** (numeratorDecimals-denominatorDecimals));
            pending += _pending;
        }
        return pending;
    }

    function getAPR() external view returns (uint) {
        DataTypes.ReserveData memory reserveData = aPool.getReserveData(address(token));
        uint liquidityApr = reserveData.currentLiquidityRate / 1e9; // currentLiquidityRate is expressed in ray, 1e27

        address[] memory rewards = aRewardsController.getRewardsByAsset(address(aToken));
        uint rewardsCount = rewards.length;
        uint _totalSupply = aToken.totalSupply();
        uint TokenPriceInUSD = PriceLib.getAssetPrice(address(token));
        uint rewardsApr;
        for (uint i = 0; i < rewardsCount; i ++) {
            address reward = rewards[i];
            (, uint emissionPerSecond,,) = aRewardsController.getRewardsData(address(aToken), reward);
            uint priceInUSD = PriceLib.getAssetPrice(address(reward));
            uint numeratorDecimals = 18 // APR precision
                                    + tokenDecimals; // against to totalSupply
            uint denominatorDecimals = IERC20UpgradeableEx(address(reward)).decimals(); // against to emissionPerSecond
            uint rewardApr = YEAR_IN_SEC * emissionPerSecond * priceInUSD * (10 ** (numeratorDecimals-denominatorDecimals))
                            / (_totalSupply * TokenPriceInUSD);
            rewardsApr += rewardApr;
        }

        return liquidityApr + (rewardsApr * (DENOMINATOR-yieldFee) / DENOMINATOR);
    }

}
