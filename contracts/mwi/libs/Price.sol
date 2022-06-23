//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

interface IChainlink {
    function latestAnswer() external view returns (int256);
}

interface IAaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

library PriceLib {
    IAaveOracle internal constant AaveOracle = IAaveOracle(0xEBd36016B3eD09D4693Ed4251c67Bd858c3c7C9C);
    address internal constant USDT = 0xc7198437980c041c805A1EDcbA50c1Ce5db95118;

    /// @return the price in USD of 8 decimals in precision.
    function getAssetPrice(address asset) internal view returns (uint) {
        if (asset == USDT) {
            return uint(IChainlink(0xEBE676ee90Fe1112671f19b6B7459bC678B67e8a).latestAnswer());
        }
        return AaveOracle.getAssetPrice(asset);
    }
}
