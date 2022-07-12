// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./libs/Price.sol";

interface IRouter {
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
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
}

interface IL2Vault is IERC20Upgradeable {
    function deposit(uint amount) external;
    function withdraw(uint share) external;
    function getAllPoolInUSD() external view returns (uint);
    function getAPR() external view returns (uint);
}

contract MWIStrategy is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant USDT = IERC20Upgradeable(0xc7198437980c041c805A1EDcbA50c1Ce5db95118);
    IERC20Upgradeable public constant WBTC = IERC20Upgradeable(0x50b7545627a5162F82A992c33b87aDc75187B218);
    IERC20Upgradeable public constant WETH = IERC20Upgradeable(0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB);
    IERC20Upgradeable public constant WAVAX = IERC20Upgradeable(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    IERC20Upgradeable public constant USDt = IERC20Upgradeable(0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7);

    IRouter public constant JoeRouter = IRouter(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);

    uint constant POOL_COUNT = 4;
    IL2Vault public WBTCVault;
    IL2Vault public WETHVault;
    IL2Vault public WAVAXVault;
    IL2Vault public USDTVault;
    
    uint constant DENOMINATOR = 10000;
    uint[] public targetPercentages;

    address public vault;

    event TargetComposition (uint WBTCTargetPool, uint WETHTargetPool, uint WAVAXTargetPool, uint USDTTargetPool);
    event CurrentComposition (uint WBTCTargetPool, uint WETHTargetPool, uint WAVAXCurrentPool, uint USDTCurrentPool);
    event InvestWBTC(uint USDTAmt, uint WBTCAmt);
    event InvestWETH(uint USDTAmt, uint WETHAmt);
    event InvestWAVAX(uint USDTAmt, uint WAVAXAmt);
    event InvestUSDT(uint USDTAmt, uint USDtAmt);
    event Withdraw(uint sharePerc, uint USDTAmt);
    event WithdrawWBTC(uint WBTCAmt, uint USDTAmt);
    event WithdrawWETH(uint WETHAmt, uint USDTAmt);
    event WithdrawWAVAX(uint WAVAXAmt, uint USDTAmt);
    event WithdrawUSDT(uint USDtAmt, uint USDTAmt);
    event EmergencyWithdraw(uint USDTAmt);

    modifier onlyVault {
        require(msg.sender == vault, "Only vault");
        _;
    }

    function initialize(IL2Vault _WBTCVault, IL2Vault _WETHVault, IL2Vault _WAVAXVault, IL2Vault _USDTVault) external initializer {
        __Ownable_init();

        targetPercentages.push(4500); // WBTC: 45%
        targetPercentages.push(3500); // WETH: 35%
        targetPercentages.push(1500); // WAVAX: 15%
        targetPercentages.push(500); // USDT: 5%

        WBTCVault = _WBTCVault;
        WETHVault = _WETHVault;
        WAVAXVault = _WAVAXVault;
        USDTVault = _USDTVault;

        USDT.safeApprove(address(JoeRouter), type(uint).max);
        WBTC.safeApprove(address(JoeRouter), type(uint).max);
        WETH.safeApprove(address(JoeRouter), type(uint).max);
        WAVAX.safeApprove(address(JoeRouter), type(uint).max);
        USDt.safeApprove(address(JoeRouter), type(uint).max);

        WBTC.safeApprove(address(WBTCVault), type(uint).max);
        WETH.safeApprove(address(WETHVault), type(uint).max);
        WAVAX.safeApprove(address(WAVAXVault), type(uint).max);
        USDt.safeApprove(address(USDTVault), type(uint).max);
    }

    function invest(uint USDTAmt) external onlyVault {
        USDT.safeTransferFrom(vault, address(this), USDTAmt);
        USDTAmt = USDT.balanceOf(address(this));
        uint USDTPriceInUSD = PriceLib.getAssetPrice(address(USDT));

        uint[] memory pools = getEachPoolInUSD();
        uint allPool = pools[0] + pools[1] + pools[2] + pools[3] + (USDTAmt * USDTPriceInUSD * 1e4); // USDT's decimals is 6

        uint totalAllocation;
        uint[] memory allocations = new uint[](POOL_COUNT);
        for (uint i = 0; i < POOL_COUNT; i ++) {
            uint target = allPool * targetPercentages[i] / DENOMINATOR;
            if (pools[i] < target) {
                uint diff = target - pools[i];
                allocations[i] = diff;
                totalAllocation += diff;
            }
        }

        uint[] memory USDTAmts = new uint[](POOL_COUNT);
        for (uint i = 0; i < POOL_COUNT; i ++) {
            USDTAmts[i] = USDTAmt * allocations[i] / totalAllocation;
        }

        if (USDTAmts[0] > 0) {
            _investWBTC(USDTAmts[0], USDTPriceInUSD);
        }
        if (USDTAmts[1] > 0) {
            _investWETH(USDTAmts[1], USDTPriceInUSD);
        }
        if (USDTAmts[2] > 0) {
            _investWAVAX(USDTAmts[2], USDTPriceInUSD);
        }
        if (USDTAmts[3] > 0) {
            _investUSDT(USDTAmts[3]);
        }

        emit CurrentComposition(pools[0], pools[1], pools[2], pools[3]);
        emit TargetComposition(targetPercentages[0], targetPercentages[1], targetPercentages[2], targetPercentages[3]);
    }

    function _investWBTC(uint USDTAmt, uint USDTPriceInUSD) private {
        uint WBTCPriceInUSD = PriceLib.getAssetPrice(address(WBTC));
        uint amountOut = USDTAmt * USDTPriceInUSD * 100 / WBTCPriceInUSD;  // USDT's decimals is 6, WBTC's decimals is 8
        uint WBTCAmt = _swap2(address(USDT), address(WBTC), USDTAmt, amountOut*95/100);
        WBTCVault.deposit(WBTCAmt);
        emit InvestWBTC(USDTAmt, WBTCAmt);
    }

    function _investWETH(uint USDTAmt, uint USDTPriceInUSD) private {
        uint WETHPriceInUSD = PriceLib.getAssetPrice(address(WETH));
        uint amountOut = USDTAmt * USDTPriceInUSD * 1e12 / WETHPriceInUSD;  // USDT's decimals is 6, WETH's decimals is 18
        uint WETHAmt = _swap2(address(USDT), address(WETH), USDTAmt, amountOut*95/100);
        WETHVault.deposit(WETHAmt);
        emit InvestWETH(USDTAmt, WETHAmt);
    }

    function _investWAVAX(uint USDTAmt, uint USDTPriceInUSD) private {
        uint WAVAXPriceInUSD = PriceLib.getAssetPrice(address(WAVAX));
        uint amountOut = USDTAmt * USDTPriceInUSD * 1e12 / WAVAXPriceInUSD;  // USDT's decimals is 6, WAVAX's decimals is 18
        uint WAVAXAmt = _swap(address(USDT), address(WAVAX), USDTAmt, amountOut*95/100);
        WAVAXVault.deposit(WAVAXAmt);
        emit InvestWAVAX(USDTAmt, WAVAXAmt);
    }

    function _investUSDT(uint USDTAmt) private {
        uint USDtAmt = _swap(address(USDT), address(USDt), USDTAmt, USDTAmt*99/100);
        USDTVault.deposit(USDtAmt);
        emit InvestUSDT(USDTAmt, USDtAmt);
    }

    function withdrawPerc(uint sharePerc) external onlyVault returns (uint USDTAmt) {
        require(sharePerc <= 1e18, "Over 100%");
        
        uint USDTAmtBefore = USDT.balanceOf(address(this));
        uint USDTPriceInUSD = PriceLib.getAssetPrice(address(USDT));

        _withdrawWBTC(sharePerc, USDTPriceInUSD);
        _withdrawWETH(sharePerc, USDTPriceInUSD);
        _withdrawWAVAX(sharePerc, USDTPriceInUSD);
        _withdrawUSDT(sharePerc);

        USDTAmt = USDT.balanceOf(address(this)) - USDTAmtBefore;
        USDT.safeTransfer(vault, USDTAmt);
        emit Withdraw(sharePerc, USDTAmt);
    }

    function _withdrawWBTC(uint _sharePerc, uint USDTPriceInUSD) private {
        uint amount = WBTCVault.balanceOf(address(this)) * _sharePerc / 1e18;
        if (0 < amount) {
            WBTCVault.withdraw(amount);

            uint WBTCAmt = WBTC.balanceOf(address(this));
            uint WBTCPriceInUSD = PriceLib.getAssetPrice(address(WBTC));
            uint amountOut = WBTCAmt * WBTCPriceInUSD / (USDTPriceInUSD * 100);  // USDT's decimals is 6, WBTC's decimals is 8
            uint USDTAmt = _swap2(address(WBTC), address(USDT), WBTCAmt, amountOut*95/100);
            emit WithdrawWBTC(WBTCAmt, USDTAmt);
        }
    }

    function _withdrawWETH(uint _sharePerc, uint USDTPriceInUSD) private {
        uint amount = WETHVault.balanceOf(address(this)) * _sharePerc / 1e18;
        if (0 < amount) {
            WETHVault.withdraw(amount);

            uint WETHAmt = WETH.balanceOf(address(this));
            uint WETHPriceInUSD = PriceLib.getAssetPrice(address(WETH));
            uint amountOut = WETHAmt * WETHPriceInUSD / (USDTPriceInUSD * 1e12);  // USDT's decimals is 6, WETH's decimals is 18
            uint USDTAmt = _swap2(address(WETH), address(USDT), WETHAmt, amountOut*95/100);
            emit WithdrawWETH(WETHAmt, USDTAmt);
        }
    }

    function _withdrawWAVAX(uint _sharePerc, uint USDTPriceInUSD) private {
        uint amount = WAVAXVault.balanceOf(address(this)) * _sharePerc / 1e18;
        if (0 < amount) {
            WAVAXVault.withdraw(amount);

            uint WAVAXAmt = WAVAX.balanceOf(address(this));
            uint WAVAXPriceInUSD = PriceLib.getAssetPrice(address(WAVAX));
            uint amountOut = WAVAXAmt * WAVAXPriceInUSD / (USDTPriceInUSD * 1e12);  // USDT's decimals is 6, WAVAX's decimals is 18
            uint USDTAmt = _swap(address(WAVAX), address(USDT), WAVAXAmt, amountOut*95/100);
            emit WithdrawWAVAX(WAVAXAmt, USDTAmt);
        }
    }

    function _withdrawUSDT(uint _sharePerc) private {
        uint amount = USDTVault.balanceOf(address(this)) * _sharePerc / 1e18;
        if (0 < amount) {
            USDTVault.withdraw(amount);

            uint USDtAmt = USDt.balanceOf(address(this));
            uint USDTAmt = _swap(address(USDt), address(USDT), USDtAmt, USDtAmt*99/100);
            emit WithdrawUSDT(USDtAmt, USDTAmt);
        }
    }

    function _swap(address _tokenA, address _tokenB, uint _amt, uint _minAmount) private returns (uint) {
        address[] memory path = new address[](2);
        path[0] = _tokenA;
        path[1] = _tokenB;
        return (JoeRouter.swapExactTokensForTokens(_amt , _minAmount, path, address(this), block.timestamp))[1];
    }

    function _swap2(address _tokenA, address _tokenB, uint _amt, uint _minAmount) private returns (uint) {
        address[] memory path = new address[](3);
        path[0] = _tokenA;
        path[1] = address(WAVAX);
        path[2] = _tokenB;
        return (JoeRouter.swapExactTokensForTokens(_amt , _minAmount, path, address(this), block.timestamp))[2];
    }

    function withdrawFromFarm(uint farmIndex, uint sharePerc) external onlyVault returns (uint USDTAmt) {
        require(sharePerc <= 1e18, "Over 100%");
        uint USDTPriceInUSD = PriceLib.getAssetPrice(address(USDT));

        if (farmIndex == 0) _withdrawWBTC(sharePerc, USDTPriceInUSD);
        else if (farmIndex == 1) _withdrawWETH(sharePerc, USDTPriceInUSD);
        else if (farmIndex == 2) _withdrawWAVAX(sharePerc, USDTPriceInUSD);
        else if (farmIndex == 3) _withdrawUSDT(sharePerc);

        USDTAmt = USDT.balanceOf(address(this));
        USDT.safeTransfer(vault, USDTAmt);
    }

    function emergencyWithdraw() external onlyVault {
        // 1e18 == 100% of share
        uint USDTPriceInUSD = PriceLib.getAssetPrice(address(USDT));

        _withdrawWBTC(1e18, USDTPriceInUSD);
        _withdrawWETH(1e18, USDTPriceInUSD);
        _withdrawWAVAX(1e18, USDTPriceInUSD);
        _withdrawUSDT(1e18);

        uint USDTAmt = USDT.balanceOf(address(this));
        if (0 < USDTAmt) {
            USDT.safeTransfer(vault, USDTAmt);
        }
        emit EmergencyWithdraw(USDTAmt);
    }

    function setVault(address _vault) external onlyOwner {
        require(vault == address(0), "Vault set");
        vault = _vault;
    }

    function setL2Vault(IL2Vault _WBTCVault, IL2Vault _WETHVault, IL2Vault _WAVAXVault, IL2Vault _USDTVault) external onlyOwner {
        WBTCVault = _WBTCVault;
        WETHVault = _WETHVault;
        WAVAXVault = _WAVAXVault;
        USDTVault = _USDTVault;
    }

    function setTokenCompositionTargetPerc(uint[] calldata _targetPerc) external onlyOwner {
        uint targetCnt = _targetPerc.length;
        require(targetCnt == targetPercentages.length, "Invalid count");

        uint sum;
        for (uint i = 0; i < targetCnt; i ++) {
            targetPercentages[i] = _targetPerc[i];
            sum += _targetPerc[i];
        }
        require(sum == DENOMINATOR, "Invalid parameter");
    }

    function getWBTCPoolInUSD() private view  returns (uint) {
        uint amt = WBTCVault.getAllPoolInUSD();
        return amt == 0 ? 0 : amt * WBTCVault.balanceOf(address(this)) / WBTCVault.totalSupply(); //to exclude L1 deposits from other addresses
    }

    function getWETHPoolInUSD() private view  returns (uint) {
        uint amt = WETHVault.getAllPoolInUSD();
        return amt == 0 ? 0 : amt * WETHVault.balanceOf(address(this)) / WETHVault.totalSupply(); //to exclude L1 deposits from other addresses
    }

    function getWAVAXPoolInUSD() private view  returns (uint) {
        uint amt = WAVAXVault.getAllPoolInUSD();
        return amt == 0 ? 0 : amt * WAVAXVault.balanceOf(address(this)) / WAVAXVault.totalSupply(); //to exclude L1 deposits from other addresses
    }

    function getUSDTPoolInUSD() private view  returns (uint) {
        uint amt = USDTVault.getAllPoolInUSD();
        return amt == 0 ? 0 : amt * USDTVault.balanceOf(address(this)) / USDTVault.totalSupply(); //to exclude L1 deposits from other addresses
    }

    function getEachPoolInUSD() private view returns (uint[] memory pools) {
        pools = new uint[](POOL_COUNT);
        pools[0] = getWBTCPoolInUSD();
        pools[1] = getWETHPoolInUSD();
        pools[2] = getWAVAXPoolInUSD();
        pools[3] = getUSDTPoolInUSD();
    }

    function getAllPoolInUSD() public view returns (uint) {
        uint[] memory pools = getEachPoolInUSD();
        return pools[0] + pools[1] + pools[2] + pools[3];
    }

    function getCurrentTokenCompositionPerc() public view returns (address[] memory tokens, uint[] memory percentages) {
        tokens = new address[](POOL_COUNT);
        tokens[0] = address(WBTC);
        tokens[1] = address(WETH);
        tokens[2] = address(WAVAX);
        tokens[3] = address(USDt);

        uint[] memory pools = getEachPoolInUSD();
        uint allPool = pools[0] + pools[1] + pools[2] + pools[3];
        percentages = new uint[](POOL_COUNT);
        for (uint i = 0; i < POOL_COUNT; i ++) {
            percentages[i] = allPool == 0 ? targetPercentages[i] : pools[i] * DENOMINATOR / allPool;
        }
    }

    function getAPR() external view returns (uint) {
        (, uint[] memory perc) = getCurrentTokenCompositionPerc();
        uint allApr = WBTCVault.getAPR() * perc[0]
                    + WETHVault.getAPR() * perc[1]
                    + WAVAXVault.getAPR() * perc[2]
                    + USDTVault.getAPR() * perc[3];
        return (allApr / DENOMINATOR);
    }

}
