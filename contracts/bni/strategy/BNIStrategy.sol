// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../priceOracle/IPriceOracle.sol";
import "../../../interfaces/IERC20UpgradeableExt.sol";
import "../../../interfaces/IUniRouter.sol";
import "../../../libs/Token.sol";

contract BNIStrategy is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20UpgradeableExt;

    IUniRouter public router;
    IERC20UpgradeableExt public SWAP_BASE_TOKEN; // It has same role with WETH on Ethereum Swaps. Most of tokens have been paired with this token.
    IERC20UpgradeableExt public USDT;
    uint8 usdtDecimals;

    uint constant DENOMINATOR = 10000;

    address public treasuryWallet;
    address public admin;
    address public vault;
    IPriceOracle public priceOracle;

    address[] public tokens;
    mapping(address => uint) public pid; // Pool indices in tokens array

    event AddToken(address token, uint pid);
    event RemoveToken(address token, uint pid);
    event Withdraw(uint sharePerc, uint USDTAmt);
    event EmergencyWithdraw(uint USDTAmt);
    event SetTreasuryWallet(address oldTreasuryWallet, address newTreasuryWallet);
    event SetAdminWallet(address oldAdmin, address newAdmin);

    modifier onlyVault {
        require(msg.sender == vault, "Only vault");
        _;
    }

    function initialize(
        address _treasuryWallet, address _admin,
        address _priceOracle,
        address _router, address _SWAP_BASE_TOKEN,
        address _USDT, address _token0
    ) public virtual initializer {
        require(_router != address(0), "Invalid router");
        require(_SWAP_BASE_TOKEN != address(0), "Invalid SWAP_BASE_TOKEN");
        require(_USDT != address(0), "Invalid USDT");
        require(_token0 != address(0), "Invalid token0");
        __Ownable_init();

        treasuryWallet = _treasuryWallet;
        admin = _admin;
        priceOracle = IPriceOracle(_priceOracle);
        router = IUniRouter(_router);
        SWAP_BASE_TOKEN = IERC20UpgradeableExt(_SWAP_BASE_TOKEN);

        USDT = IERC20UpgradeableExt(_USDT);
        usdtDecimals = USDT.decimals();
        require(6 <= usdtDecimals, "USDT decimals must >= 6");

        tokens.push(_token0);
        updatePid();

        USDT.safeApprove(address(router), type(uint).max);
        IERC20UpgradeableExt(_token0).safeApprove(address(router), type(uint).max);
    }

    function updatePid() internal {
        address[] memory _tokens = tokens;

        uint tokenCnt = _tokens.length;
        for (uint i = 0; i < tokenCnt; i ++) {
            pid[_tokens[i]] = i;
        }
    }

    function addToken(address _token) external onlyOwner {
        uint _pid = pid[_token];
        require ((_pid == 0 && _token != tokens[0]), "Already added");

        tokens.push(_token);
        _pid = tokens.length-1;
        pid[_token] = _pid;

        if (IERC20UpgradeableExt(_token).allowance(address(this), address(router)) == 0) {
            IERC20UpgradeableExt(_token).safeApprove(address(router), type(uint).max);
        }
        emit AddToken(_token, _pid);
    }

    function removeToken(uint _pid) external onlyOwner {
        uint tokenCnt = tokens.length;
        require(_pid < tokenCnt, "Invalid pid");
        uint pool = _getPoolInUSD(_pid);
        require(pool == 0, "Pool is not empty");

        address _token = tokens[_pid];
        tokens[_pid] = tokens[tokenCnt-1];
        tokens.pop();

        pid[_token] = 0;
        updatePid();

        emit RemoveToken(_token, _pid);
    }

    /// @param _USDTAmts amounts of USDT should be deposited to each pools. They have been denominated in USDT decimals
    function invest(address[] memory _tokens, uint[] memory _USDTAmts) external onlyVault {
        uint poolCnt = _tokens.length;
        uint USDTAmt;
        uint[] memory USDTAmts = new uint[](tokens.length);
        for (uint i = 0; i < poolCnt; i ++) {
            uint amount = _USDTAmts[i];
            USDTAmt += amount;
            uint _pid = pid[_tokens[i]];
            USDTAmts[_pid] += amount;
        }
        USDT.safeTransferFrom(vault, address(this), USDTAmt);

        _invest(USDTAmts);
    }

    function _invest(uint[] memory _USDTAmts) internal virtual {
        uint poolCnt = _USDTAmts.length;
        for (uint i = 0; i < poolCnt; i ++) {
            address token = tokens[i];
            if (token == address(USDT)) continue;

            uint USDTAmt = _USDTAmts[i];
            (uint USDTPriceInUSD, uint8 USDTPriceDecimals) = getUSDTPriceInUSD();
            (uint TOKENPriceInUSD, uint8 TOKENPriceDecimals) = priceOracle.getAssetPrice(token);
            uint8 tokenDecimals = IERC20UpgradeableExt(token).decimals();
            uint numerator = USDTPriceInUSD * (10 ** (TOKENPriceDecimals + tokenDecimals));
            uint denominator = TOKENPriceInUSD * (10 ** (USDTPriceDecimals + usdtDecimals));
            uint amountOutMin = USDTAmt * numerator * 95 / (denominator * 100);

            if (token == address(SWAP_BASE_TOKEN)) {
                _swap(address(USDT), token, USDTAmt, amountOutMin);
            } else {
                _swap2(address(USDT), token, USDTAmt, amountOutMin);
            }
        }
    }

    function withdrawPerc(uint _sharePerc) external onlyVault returns (uint USDTAmt) {
        require(_sharePerc <= 1e18, "Over 100%");
        USDTAmt = _withdraw(_sharePerc);
        USDT.safeTransfer(vault, USDTAmt);
        emit Withdraw(_sharePerc, USDTAmt);
    }

    function _withdraw(uint _sharePerc) internal virtual returns (uint USDTAmt) {
        uint poolCnt = tokens.length;
        for (uint i = 0; i < poolCnt; i ++) {
            USDTAmt += _withdrawFromPool(i, _sharePerc);
        }
    }

    function _withdrawFromPool(uint _pid, uint _sharePerc) internal virtual returns (uint USDTAmt) {
        IERC20UpgradeableExt token = IERC20UpgradeableExt(tokens[_pid]);
        uint amount = token.balanceOf(address(this)) * _sharePerc / 1e18;
        if (0 < amount) {
            if (address(token) == address(USDT)) {
                USDTAmt = amount;
            } else {
                USDTAmt = _swapForUSDT(address(token), amount);
            }
        }
    }

    function _swapForUSDT(address token, uint amount) internal returns (uint USDTAmt) {
        (uint USDTPriceInUSD, uint8 USDTPriceDecimals) = getUSDTPriceInUSD();
        (uint TOKENPriceInUSD, uint8 TOKENPriceDecimals) = priceOracle.getAssetPrice(address(token));
        uint8 tokenDecimals = IERC20UpgradeableExt(token).decimals();
        uint numerator = TOKENPriceInUSD * (10 ** (USDTPriceDecimals + usdtDecimals));
        uint denominator = USDTPriceInUSD * (10 ** (TOKENPriceDecimals + tokenDecimals));
        uint amountOutMin = amount * numerator * 95 / (denominator * 100);

        if (address(token) == address(SWAP_BASE_TOKEN)) {
            USDTAmt = _swap(address(token), address(USDT), amount, amountOutMin);
        } else{
            USDTAmt = _swap2(address(token), address(USDT), amount, amountOutMin);
        }
    }

    function _swap(address _tokenA, address _tokenB, uint _amt, uint _minAmount) private returns (uint) {
        address[] memory path = new address[](2);
        path[0] = _tokenA;
        path[1] = _tokenB;
        return (router.swapExactTokensForTokens(_amt, _minAmount, path, address(this), block.timestamp))[1];
    }

    function _swap2(address _tokenA, address _tokenB, uint _amt, uint _minAmount) private returns (uint) {
        address[] memory path = new address[](3);
        path[0] = _tokenA;
        path[1] = address(SWAP_BASE_TOKEN);
        path[2] = _tokenB;
        return (router.swapExactTokensForTokens(_amt, _minAmount, path, address(this), block.timestamp))[2];
    }

    function withdrawFromPool(uint _pid, uint _sharePerc) external onlyVault returns (uint USDTAmt) {
        require(_sharePerc <= 1e18, "Over 100%");
        USDTAmt = _withdrawFromPool(_pid, _sharePerc);
        USDT.safeTransfer(vault, USDTAmt);
    }

    function emergencyWithdraw() external onlyVault {
        // 1e18 == 100% of share
        uint USDTAmt = _withdraw(1e18);
        if (0 < USDTAmt) {
            USDT.safeTransfer(vault, USDTAmt);
        }
        emit EmergencyWithdraw(USDTAmt);
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

    function setVault(address _vault) external onlyOwner {
        require(vault == address(0), "Vault set");
        vault = _vault;
    }

    /// @return the price of USDT in USD.
    function getUSDTPriceInUSD() public view returns(uint, uint8) {
        return priceOracle.getAssetPrice(address(USDT));
    }

    function getEachPoolInUSD() public view returns (address[] memory, uint[] memory pools) {
        return (tokens, _getEachPoolInUSD());
    }

    function _getEachPoolInUSD() private view returns (uint[] memory pools) {
        uint poolCnt = tokens.length;
        pools = new uint[](poolCnt);
        for (uint i = 0; i < poolCnt; i ++) {
            pools[i] = _getPoolInUSD(i);
        }
    }

    function _getPoolInUSD(uint _pid) internal view virtual returns (uint pool) {
        IERC20UpgradeableExt token = IERC20UpgradeableExt(tokens[_pid]);
        uint amount = token.balanceOf(address(this));
        if (0 < amount) {
            (uint TOKENPriceInUSD, uint8 TOKENPriceDecimals) = priceOracle.getAssetPrice(address(token));
            uint8 tokenDecimals = IERC20UpgradeableExt(token).decimals();
            pool = Token.changeDecimals(amount, tokenDecimals, 18) * TOKENPriceInUSD / (10 ** (TOKENPriceDecimals));
        }
    }

    function getAllPoolInUSD() public view returns (uint) {
        uint[] memory pools = _getEachPoolInUSD();
        uint poolCnt = pools.length;
        uint allPool;
        for (uint i = 0; i < poolCnt; i ++) {
            allPool += pools[i];
        }
        return allPool;
    }

    function getCurrentTokenCompositionPerc() public view returns (address[] memory, uint[] memory percentages) {
        uint[] memory pools = _getEachPoolInUSD();
        uint poolCnt = pools.length;
        uint allPool;
        for (uint i = 0; i < poolCnt; i ++) {
            allPool += pools[i];
        }

        uint defaultTargetPerc = poolCnt == 0 ? 0 : DENOMINATOR / poolCnt;
        percentages = new uint[](poolCnt);
        for (uint i = 0; i < poolCnt; i ++) {
            percentages[i] = allPool == 0 ? defaultTargetPerc : pools[i] * DENOMINATOR / allPool;
        }
        return (tokens, percentages);
    }

    function getAPR() public view virtual returns (uint) {
        return 0;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[40] private __gap;
}
