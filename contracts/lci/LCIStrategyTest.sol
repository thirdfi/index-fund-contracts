// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

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

contract LCIStrategyTest is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant USDT = IERC20Upgradeable(0x1F326a8CA5399418a76eA0efa0403Cbb00790C67);
    IERC20Upgradeable public constant USDC = IERC20Upgradeable(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IERC20Upgradeable public constant BUSD = IERC20Upgradeable(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20Upgradeable public constant USDT_MAIN = IERC20Upgradeable(0x55d398326f99059fF775485246999027B3197955);
    IERC20Upgradeable public constant USDC_MAIN = IERC20Upgradeable(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IERC20Upgradeable public constant BUSD_MAIN = IERC20Upgradeable(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    IERC20Upgradeable public constant USDTUSDC = IERC20Upgradeable(0xEc6557348085Aa57C72514D67070dC863C0a5A8c);
    IERC20Upgradeable public constant USDTBUSD = IERC20Upgradeable(0x7EFaEf62fDdCCa950418312c6C91Aef321375A00);
    IERC20Upgradeable public constant USDCBUSD = IERC20Upgradeable(0x2354ef4DF11afacb85a5C7f98B624072ECcddbB1);

    IRouter public constant PnckRouter = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    IL2Vault public USDTUSDCVault;
    IL2Vault public USDTBUSDVault;
    IL2Vault public USDCBUSDVault;
    
    uint constant DENOMINATOR = 10000;
    uint constant USDTUSDCTargetPerc = 6000; // 60%
    uint constant USDTBUSDTargetPerc = 2000; // 20%
    uint constant USDCBUSDTargetPerc = 2000; // 20%

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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IL2Vault _USDTUSDCVault, IL2Vault _USDTBUSDVault, IL2Vault _USDCBUSDVault) external initializer {
        __Ownable_init();

        USDTUSDCVault = _USDTUSDCVault;
        USDTBUSDVault = _USDTBUSDVault;
        USDCBUSDVault = _USDCBUSDVault;

        // USDT.safeApprove(address(PnckRouter), type(uint).max);
        // USDC.safeApprove(address(PnckRouter), type(uint).max);
        // BUSD.safeApprove(address(PnckRouter), type(uint).max);

        // USDTUSDC.safeApprove(address(USDTUSDCVault), type(uint).max);
        // USDTBUSD.safeApprove(address(USDTBUSDVault), type(uint).max);
        // USDCBUSD.safeApprove(address(USDCBUSDVault), type(uint).max);

        // USDTUSDC.safeApprove(address(PnckRouter), type(uint).max);
        // USDTBUSD.safeApprove(address(PnckRouter), type(uint).max);
        // USDCBUSD.safeApprove(address(PnckRouter), type(uint).max);
    }

    function invest(uint USDTAmt) external onlyVault {
        USDT.safeTransferFrom(vault, address(this), USDTAmt);
        // USDTAmt = USDT.balanceOf(address(this));
        
        // uint[] memory pools = getEachPoolInUSD();
        // uint pool = pools[0] + pools[1] + pools[2] + USDTAmt; // USDT's decimals is 18
        // uint USDTUSDCTargetPool = pool * USDTUSDCTargetPerc / DENOMINATOR;
        // uint USDTBUSDTargetPool = pool * USDTBUSDTargetPerc / DENOMINATOR;
        // uint USDCBUSDTargetPool = pool * USDCBUSDTargetPerc / DENOMINATOR;

        // // Rebalancing invest
        // if (
        //     USDTUSDCTargetPool > pools[0] &&
        //     USDTBUSDTargetPool > pools[1] &&
        //     USDCBUSDTargetPool > pools[2]
        // ) {
        //     _investUSDTUSDC(USDTUSDCTargetPool - pools[0]);
        //     _investUSDTBUSD(USDTBUSDTargetPool - pools[1]);
        //     _investUSDCBUSD(USDCBUSDTargetPool - pools[2]);
        // } else {
        //     uint furthest;
        //     uint farmIndex;
        //     uint diff;

        //     if (USDTUSDCTargetPool > pools[0]) {
        //         diff = USDTUSDCTargetPool - pools[0];
        //         furthest = diff;
        //         farmIndex = 0;
        //     }
        //     if (USDTBUSDTargetPool > pools[1]) {
        //         diff = USDTBUSDTargetPool - pools[1];
        //         if (diff > furthest) {
        //             furthest = diff;
        //             farmIndex = 1;
        //         }
        //     }
        //     if (USDTBUSDTargetPool > pools[2]) {
        //         diff = USDTBUSDTargetPool - pools[2];
        //         if (diff > furthest) {
        //             farmIndex = 2;
        //         }
        //     }

        //     if (farmIndex == 0) _investUSDTUSDC(USDTAmt);
        //     else if (farmIndex == 1) _investUSDTBUSD(USDTAmt);
        //     else _investUSDCBUSD(USDTAmt);
        // }

        // emit TargetComposition(USDTUSDCTargetPool, USDTBUSDTargetPool, USDCBUSDTargetPool);
        // emit CurrentComposition(pools[0], pools[1], pools[2]);
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
        
        // uint USDTAmtBefore = USDT.balanceOf(address(this));
        // _withdrawUSDTUSDC(sharePerc);
        // _withdrawUSDTBUSD(sharePerc);
        // _withdrawUSDCBUSD(sharePerc);
        // USDTAmt = USDT.balanceOf(address(this)) - USDTAmtBefore;
        USDTAmt = USDT.balanceOf(address(this)) * sharePerc / 1e18;
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
        farmIndex;
        // require(sharePerc <= 1e18, "Over 100%");
        // if (farmIndex == 0) _withdrawUSDTUSDC(sharePerc); 
        // else if (farmIndex == 1) _withdrawUSDTBUSD(sharePerc);
        // else if (farmIndex == 2) _withdrawUSDCBUSD(sharePerc);
        // USDTAmt = USDT.balanceOf(address(this));
        USDTAmt = USDT.balanceOf(address(this)) * sharePerc / 1e18;
        USDT.safeTransfer(vault, USDTAmt);
    }

    function setVault(address _vault) external onlyOwner {
        require(vault == address(0), "Vault set");
        vault = _vault;
    }

    function emergencyWithdraw() external onlyVault {
        // 1e18 == 100% of share
        // _withdrawUSDTUSDC(1e18);
        // _withdrawUSDTBUSD(1e18);
        // _withdrawUSDCBUSD(1e18);
        uint USDTAmt = USDT.balanceOf(address(this));
        if (0 < USDTAmt) {
            USDT.safeTransfer(vault, USDTAmt);
        }
        emit EmergencyWithdraw(USDTAmt);
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
        pools = new uint[](3);
        // pools[0] = getUSDTUSDCPoolInUSD();
        // pools[1] = getUSDTBUSDPoolInUSD();
        // pools[2] = getUSDCBUSDPoolInUSD();
    }

    function getAllPoolInUSD() public view returns (uint) {
        // uint[] memory pools = getEachPoolInUSD();
        // return pools[0] + pools[1] + pools[2];
        return USDT.balanceOf(address(this));
    }

    function getCurrentLPCompositionPerc() public view returns (uint[] memory percentages) {
        uint[] memory pools = getEachPoolInUSD();
        uint allPool = pools[0] + pools[1] + pools[2];
        percentages = new uint[](3);
        percentages[0] = allPool == 0 ? USDTUSDCTargetPerc : pools[0] * DENOMINATOR / allPool;
        percentages[1] = allPool == 0 ? USDTBUSDTargetPerc : pools[1] * DENOMINATOR / allPool;
        percentages[2] = allPool == 0 ? USDCBUSDTargetPerc : pools[2] * DENOMINATOR / allPool;
    }

    function getCurrentTokenCompositionPerc() external view returns (address[] memory tokens, uint[] memory percentages) {
        uint[] memory lpPerc = getCurrentLPCompositionPerc();
        tokens = new address[](3);
        tokens[0] = address(USDT_MAIN);
        tokens[1] = address(USDC_MAIN);
        tokens[2] = address(BUSD_MAIN);
        percentages = new uint[](3);
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
