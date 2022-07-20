//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./PriceOracle.sol";
import "../constant/AuroraConstant.sol";

interface IUniPair is IERC20Upgradeable{
    function getReserves() external view returns (uint, uint);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IERC20UpgradeableExt is IERC20Upgradeable {
    function decimals() external view returns (uint8);
}

contract AuroraPriceOracle is PriceOracle {

    IUniPair constant BSTNWNEAR = IUniPair(0xBBf3D4281F10E537d5b13CA80bE22362310b2bf9);
    IUniPair constant METAWNEAR = IUniPair(0xa8CAaf35c0136033294dD286A14051fBf37aed07);
    IUniPair constant USDCWNEAR = IUniPair(0x20F8AeFB5697B77E0BB835A8518BE70775cdA1b0);
    IUniPair constant USDTWNEAR = IUniPair(0x03B666f3488a7992b2385B12dF7f35156d7b29cD);

    function initialize() public virtual override initializer {
        super.initialize();
    }

    ///@notice Chainlink is not yet supported on Aurora.
    function getAssetPrice(address asset) public virtual override view returns (uint price, uint8 decimals) {
        if (asset == AuroraConstant.USDT || asset == AuroraConstant.USDC) {
            return (1e8, 8);
        } else if (asset == AuroraConstant.WNEAR) {
            return getWNEARPrice();
        } else if (asset == AuroraConstant.BSTN) {
            return getBSTNPrice();
        } else if (asset == AuroraConstant.META) {
            return getMETAPrice();
        }
        return super.getAssetPrice(asset);
    }

    function getWNEARPrice() public view returns (uint price, uint8 decimals) {
        uint priceInUSDT = getPriceFromPair(USDTWNEAR, AuroraConstant.WNEAR);
        uint priceInUSDC = getPriceFromPair(USDCWNEAR, AuroraConstant.WNEAR);
        return ((priceInUSDT + priceInUSDC) / 2, 18);
    }

    function getBSTNPrice() private view returns (uint price, uint8 decimals) {
        uint priceInWNEAR = getPriceFromPair(BSTNWNEAR, AuroraConstant.BSTN);
        (uint WNEARPriceInUSD, uint8 WNEARPriceDecimals) = getWNEARPrice();
        price = priceInWNEAR * WNEARPriceInUSD / 1e18;
        decimals = WNEARPriceDecimals;
    }

    function getMETAPrice() private view returns (uint price, uint8 decimals) {
        uint priceInWNEAR = getPriceFromPair(METAWNEAR, AuroraConstant.META);
        (uint WNEARPriceInUSD, uint8 WNEARPriceDecimals) = getWNEARPrice();
        price = priceInWNEAR * WNEARPriceInUSD / 1e18;
        decimals = WNEARPriceDecimals;
    }

    ///@return the value denominated with other token. It's 18 decimals.
    function getPriceFromPair(IUniPair pair, address token) private view returns (uint) {
        (uint _reserve0, uint _reserve1) = pair.getReserves();
        address token0 = pair.token0();
        address token1 = pair.token1();
        uint8 decimals0 = IERC20UpgradeableExt(token0).decimals();
        uint8 decimals1 = IERC20UpgradeableExt(token1).decimals();

        uint numerator;
        uint denominator;
        if (token0 == token) {
            numerator = _reserve1 * (10 ** (18 + decimals0));
            denominator = _reserve0 * (10 ** (decimals1));
        } else if (token1 == token) {
            numerator = _reserve0 * (10 ** (18 + decimals1));
            denominator = _reserve1 * (10 ** (decimals0));
        } else {
            require(false, "Invalid pair and token");
        }

        return (numerator / denominator);
    }
}
