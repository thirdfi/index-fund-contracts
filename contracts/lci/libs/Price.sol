//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

interface IChainlink {
    function latestAnswer() external view returns (int256);
}

library PriceLib {
    function getBNBPriceInUSD() internal view returns (uint, uint) {
        uint BNBPriceInUSD = uint(IChainlink(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE).latestAnswer()); // 8 decimals
        return (BNBPriceInUSD, 1e8);
    }

    function getCAKEPriceInUSD() internal view returns (uint, uint) {
        uint CAKEPriceInUSD = uint(IChainlink(0xB6064eD41d4f67e353768aA239cA86f4F73665a1).latestAnswer()); // 8 decimals
        return (CAKEPriceInUSD, 1e8);
    }
}
