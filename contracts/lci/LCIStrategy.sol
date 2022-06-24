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

contract LCIStrategy is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant USDT = IERC20Upgradeable(0x55d398326f99059fF775485246999027B3197955);
    IERC20Upgradeable public constant USDC = IERC20Upgradeable(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IERC20Upgradeable public constant BUSD = IERC20Upgradeable(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    IERC20Upgradeable public constant USDTUSDC = IERC20Upgradeable(0xEc6557348085Aa57C72514D67070dC863C0a5A8c);
    IERC20Upgradeable public constant USDTBUSD = IERC20Upgradeable(0x7EFaEf62fDdCCa950418312c6C91Aef321375A00);
    IERC20Upgradeable public constant USDCBUSD = IERC20Upgradeable(0x2354ef4DF11afacb85a5C7f98B624072ECcddbB1);

    IRouter public constant PnckRouter = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    uint constant POOL_COUNT = 3;
    IL2Vault public USDTUSDCVault;
    IL2Vault public USDTBUSDVault;
    IL2Vault public USDCBUSDVault;
    
    uint constant DENOMINATOR = 10000;
    uint[] public targetPercentages;

    address public vault;

    event TargetComposition (uint USDTUSDCTargetPool, uint USDTBUSDTargetPool, uint USDCBUSDTargetPool);
    event CurrentComposition (uint USDTUSDCTargetPool, uint USDTBUSDTargetPool, uint USDCBUSDCurrentPool);
    event InvestUSDTUSDC(uint USDTAmt, uint USDTUSDCAmt);
    event InvestUSDTBUSD(uint USDTAmt, uint USDTBUSDAmt);
    event InvestUSDCBUSD(uint USDTAmt, uint USDCBUSDAmt);
    event Withdraw(uint sharePerc, uint USDTAmt);
    event WithdrawUSDTUSDC(uint lpTokenAmt, uint USDTAmt);
    event WithdrawUSDTBUSD(uint lpTokenAmt, uint USDTAmt);
    event WithdrawUSDCBUSD(uint lpTokenAmt, uint USDTAmt);
    event EmergencyWithdraw(uint USDTAmt);

    modifier onlyVault {
        require(msg.sender == vault, "Only vault");
        _;
    }

    function initialize(IL2Vault _USDTUSDCVault, IL2Vault _USDTBUSDVault, IL2Vault _USDCBUSDVault) external initializer {
        __Ownable_init();

        targetPercentages.push(6000); // 60%
        targetPercentages.push(2000); // 20%
        targetPercentages.push(2000); // 20%

        USDTUSDCVault = _USDTUSDCVault;
        USDTBUSDVault = _USDTBUSDVault;
        USDCBUSDVault = _USDCBUSDVault;

        USDT.safeApprove(address(PnckRouter), type(uint).max);
        USDC.safeApprove(address(PnckRouter), type(uint).max);
        BUSD.safeApprove(address(PnckRouter), type(uint).max);

        USDTUSDC.safeApprove(address(USDTUSDCVault), type(uint).max);
        USDTBUSD.safeApprove(address(USDTBUSDVault), type(uint).max);
        USDCBUSD.safeApprove(address(USDCBUSDVault), type(uint).max);

        USDTUSDC.safeApprove(address(PnckRouter), type(uint).max);
        USDTBUSD.safeApprove(address(PnckRouter), type(uint).max);
        USDCBUSD.safeApprove(address(PnckRouter), type(uint).max);
    }

    function invest(uint USDTAmt) external onlyVault {
        USDT.safeTransferFrom(vault, address(this), USDTAmt);
        USDTAmt = USDT.balanceOf(address(this));
        (uint USDTPriceInUSD, uint denominator) = PriceLib.getUSDTPriceInUSD();

        uint[] memory pools = getEachPoolInUSD();
        uint allPool = pools[0] + pools[1] + pools[2] + USDTAmt * USDTPriceInUSD / denominator; // USDT's decimals is 18

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
            _investUSDTUSDC(USDTAmts[0]);
        }
        if (USDTAmts[1] > 0) {
            _investUSDTBUSD(USDTAmts[1]);
        }
        if (USDTAmts[2] > 0) {
            _investUSDCBUSD(USDTAmts[2]);
        }

        emit CurrentComposition(pools[0], pools[1], pools[2]);
        emit TargetComposition(targetPercentages[0], targetPercentages[1], targetPercentages[2]);
    }


    function _investUSDTUSDC(uint _usdtAmt) private {
        uint _amt = _usdtAmt/2;
        _swap(address(USDT), address(USDC), _amt, _amt*98/100);

        uint _USDCAmt = USDC.balanceOf(address(this));
        uint lpTokens = _addLiquidity(address(USDT), address(USDC), _amt, _USDCAmt);

        USDTUSDCVault.deposit(lpTokens);
        emit InvestUSDTUSDC(_usdtAmt, lpTokens);
    }

    function _investUSDTBUSD(uint _usdtAmt) private {
        uint _amt = _usdtAmt / 2 ;
        _swap(address(USDT), address(BUSD), _amt, _amt*98/100);

        uint _BUSDAmt = BUSD.balanceOf(address(this));
        uint lpTokens = _addLiquidity(address(USDT), address(BUSD), _amt, _BUSDAmt);

        USDTBUSDVault.deposit(lpTokens);
        emit InvestUSDTBUSD(_usdtAmt, lpTokens);
    }

    function _investUSDCBUSD(uint _usdtAmt) private {
        uint _amt = _usdtAmt / 2 ;
        _swap(address(USDT), address(USDC), _amt, _amt*98/100);
        _swap(address(USDT), address(BUSD), _amt, _amt*98/100);

        uint _USDCAmt = USDC.balanceOf(address(this));
        uint _BUSDAmt = BUSD.balanceOf(address(this));

        uint lpTokens = _addLiquidity(address(USDC), address(BUSD), _USDCAmt, _BUSDAmt);

        USDCBUSDVault.deposit(lpTokens);
        emit InvestUSDCBUSD(_usdtAmt, lpTokens);
    }

    function withdrawPerc(uint sharePerc) external onlyVault returns (uint USDTAmt) {
        require(sharePerc <= 1e18, "Over 100%");
        
        uint USDTAmtBefore = USDT.balanceOf(address(this));
        _withdrawUSDTUSDC(sharePerc);
        _withdrawUSDTBUSD(sharePerc);
        _withdrawUSDCBUSD(sharePerc);
        USDTAmt = USDT.balanceOf(address(this)) - USDTAmtBefore;
        USDT.safeTransfer(vault, USDTAmt);

        emit Withdraw(sharePerc, USDTAmt);
    }

    function _withdrawUSDTUSDC(uint _sharePerc) private {
        uint amount = USDTUSDCVault.balanceOf(address(this)) * _sharePerc / 1e18;
        if (0 < amount) {
            USDTUSDCVault.withdraw(amount);

            uint _amt = USDTUSDC.balanceOf(address(this));
            (uint _amtUSDT, uint _amtUSDC) = _removeLiquidity(address(USDT), address(USDC), _amt);
            _amtUSDT += _swap(address(USDC), address(USDT), _amtUSDC, _amtUSDC*98/100);

            emit WithdrawUSDTUSDC(_amt, _amtUSDT);
        }
    }

    function _withdrawUSDTBUSD(uint _sharePerc) private {
        uint amount = USDTBUSDVault.balanceOf(address(this)) * _sharePerc / 1e18;
        if (0 < amount) {
            USDTBUSDVault.withdraw(amount);

            uint _amt = USDTBUSD.balanceOf(address(this));
            (uint _amtUSDT, uint _amtBUSD) = _removeLiquidity(address(USDT), address(BUSD), _amt);
            _amtUSDT += _swap(address(BUSD), address(USDT), _amtBUSD, _amtBUSD*98/100);

            emit WithdrawUSDTBUSD(_amt, _amtUSDT);
        }
    }

    function _withdrawUSDCBUSD(uint _sharePerc) private {
        uint amount = USDCBUSDVault.balanceOf(address(this)) * _sharePerc / 1e18;
        if (0 < amount) {
            USDCBUSDVault.withdraw(amount);

            uint _amt = USDCBUSD.balanceOf(address(this));
            (uint _amtUSDC, uint _amtBUSD) = _removeLiquidity(address(USDC), address(BUSD), _amt);
            uint _usdtAmt = _swap(address(USDC), address(USDT), _amtUSDC, _amtUSDC*98/100);
            _usdtAmt += _swap(address(BUSD), address(USDT), _amtBUSD, _amtBUSD*98/100);

            emit WithdrawUSDCBUSD(_amt, _usdtAmt);
        }
    }

    function _swap(address _tokenA, address _tokenB, uint _amt, uint _minAmount) private returns (uint) {
        address[] memory path = new address[](2);
        path[0] = _tokenA;
        path[1] = _tokenB;
        return (PnckRouter.swapExactTokensForTokens(_amt , _minAmount, path, address(this), block.timestamp))[1];
    }

    function _addLiquidity(address _tokenA, address _tokenB, uint _amtA, uint _amtB) private returns (uint liquidity) {
        (,,liquidity) = PnckRouter.addLiquidity(_tokenA, _tokenB, _amtA, _amtB, 0, 0, address(this), block.timestamp);
    }

    function _removeLiquidity(address _tokenA, address _tokenB, uint _amt) private returns (uint _amtA, uint _amtB) {
        (_amtA, _amtB) = PnckRouter.removeLiquidity(_tokenA, _tokenB, _amt, 0, 0, address(this), block.timestamp);
    }

    function withdrawFromFarm(uint farmIndex, uint sharePerc) external onlyVault returns (uint USDTAmt) {
        require(sharePerc <= 1e18, "Over 100%");
        if (farmIndex == 0) _withdrawUSDTUSDC(sharePerc); 
        else if (farmIndex == 1) _withdrawUSDTBUSD(sharePerc);
        else if (farmIndex == 2) _withdrawUSDCBUSD(sharePerc);
        USDTAmt = USDT.balanceOf(address(this));
        USDT.safeTransfer(vault, USDTAmt);
    }

    function emergencyWithdraw() external onlyVault {
        // 1e18 == 100% of share
        _withdrawUSDTUSDC(1e18);
        _withdrawUSDTBUSD(1e18);
        _withdrawUSDCBUSD(1e18);
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

    function setLPCompositionTargetPerc(uint[] calldata _targetPerc) external onlyOwner {
        uint targetCnt = _targetPerc.length;
        require(targetCnt == targetPercentages.length, "Invalid count");

        uint sum;
        for (uint i = 0; i < targetCnt; i ++) {
            targetPercentages[i] = _targetPerc[i];
            sum += _targetPerc[i];
        }
        require(sum == DENOMINATOR, "Invalid parameter");
    }

    function getUSDTUSDCPoolInUSD() private view  returns (uint) {
        uint amt = USDTUSDCVault.getAllPoolInUSD();
        return amt == 0 ? 0 : amt * USDTUSDCVault.balanceOf(address(this)) / USDTUSDCVault.totalSupply(); //to exclude L1 deposits from other addresses
    }

    function getUSDTBUSDPoolInUSD() private view returns (uint) {
        uint amt = USDTBUSDVault.getAllPoolInUSD();
        return amt == 0 ? 0 : amt * USDTBUSDVault.balanceOf(address(this)) / USDTBUSDVault.totalSupply();
    }

    function getUSDCBUSDPoolInUSD() private view returns (uint) {
        uint amt = USDCBUSDVault.getAllPoolInUSD();
        return amt == 0 ? 0 : amt * USDCBUSDVault.balanceOf(address(this)) / USDCBUSDVault.totalSupply();
    }

    function getEachPoolInUSD() private view returns (uint[] memory pools) {
        pools = new uint[](POOL_COUNT);
        pools[0] = getUSDTUSDCPoolInUSD();
        pools[1] = getUSDTBUSDPoolInUSD();
        pools[2] = getUSDCBUSDPoolInUSD();
    }

    function getAllPoolInUSD() public view returns (uint) {
        uint[] memory pools = getEachPoolInUSD();
        return pools[0] + pools[1] + pools[2];
    }

    function getCurrentLPCompositionPerc() public view returns (uint[] memory percentages) {
        uint[] memory pools = getEachPoolInUSD();
        uint allPool = pools[0] + pools[1] + pools[2];
        percentages = new uint[](POOL_COUNT);
        for (uint i = 0; i < POOL_COUNT; i ++) {
            percentages[i] = allPool == 0 ? targetPercentages[i] : pools[i] * DENOMINATOR / allPool;
        }
    }

    function getCurrentTokenCompositionPerc() external view returns (address[] memory tokens, uint[] memory percentages) {
        uint[] memory lpPerc = getCurrentLPCompositionPerc();
        tokens = new address[](POOL_COUNT);
        tokens[0] = address(USDT);
        tokens[1] = address(USDC);
        tokens[2] = address(BUSD);
        percentages = new uint[](POOL_COUNT);
        percentages[0] = (lpPerc[0] + lpPerc[1]) / 2;
        percentages[1] = (lpPerc[0] + lpPerc[2]) / 2;
        percentages[2] = (lpPerc[1] + lpPerc[2]) / 2;
    }

    function getAPR() external view returns (uint) {
        uint[] memory lpPerc = getCurrentLPCompositionPerc();
        uint allApr = USDTUSDCVault.getAPR() * lpPerc[0]
                    + USDTBUSDVault.getAPR() * lpPerc[1]
                    + USDCBUSDVault.getAPR() * lpPerc[2];
        return (allApr / DENOMINATOR);
    }

}
