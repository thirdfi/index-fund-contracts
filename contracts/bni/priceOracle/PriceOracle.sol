//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./IPriceOracle.sol";

interface IChainlinkAggregator {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 _roundId) external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

    function latestAnswer() external view returns (int256);
}

contract PriceOracle is IPriceOracle, OwnableUpgradeable {
    
    // Map of asset price sources (asset => priceSource)
    mapping(address => IChainlinkAggregator) internal assetsSources;

    function initialize() public virtual initializer {
        __Ownable_init();
    }

    function setAssetSources(address[] memory assets, address[] memory sources) public override onlyOwner {
        uint count = assets.length;
        require(count == sources.length, "Not match array length");
        for (uint i = 0; i < count; i ++) {
            assetsSources[assets[i]] = IChainlinkAggregator(sources[i]);
        }
    }

    function getSourceOfAsset(address asset) public override view returns (address) {
        return address(assetsSources[asset]);
    }

    function getAssetsPrices(address[] memory assets) public override view returns (uint[] memory prices, uint8[] memory decimalsArray) {
        uint count = assets.length;
        prices = new uint[](count);
        decimalsArray = new uint8[](count);
        for (uint i = 0; i < count; i ++) {
            (uint price, uint8 decimals) = getAssetPrice(assets[i]);
            prices[i] = price;
            decimalsArray[i] = decimals;
        }
    }

    function getAssetPrice(address asset) public virtual override view returns (uint price, uint8 decimals) {
        IChainlinkAggregator source = assetsSources[asset];
        if (address(source) != address(0)) {
            int256 _price = source.latestAnswer();
            if (_price > 0) {
                price = uint(_price);
            }
            decimals = source.decimals();
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
