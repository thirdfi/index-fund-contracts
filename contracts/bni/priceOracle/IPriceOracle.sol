//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

interface IPriceOracle {

    /**
     * @notice Sets or replaces price sources of assets
     * @param assets The addresses of the assets
     * @param sources The addresses of the price sources
     */
    function setAssetSources(address[] memory assets, address[] memory sources) external;

    /**
     * @notice Returns the address of the source for an asset address
     * @param asset The address of the asset
     * @return The address of the source
     */
    function getSourceOfAsset(address asset) external view returns (address);

    /**
     * @notice Returns a list of prices from a list of assets addresses
     * @param assets The list of assets addresses
     * @return prices The prices of the given assets
     */
    function getAssetsPrices(address[] memory assets) external view returns (uint[] memory prices, uint8[] memory decimalsArray);

    /**
     * @notice Returns a list of prices from a list of assets addresses
     * @param asset The asset address
     * @return price The prices of the given assets
     */
    function getAssetPrice(address asset) external view returns (uint price, uint8 decimals);
}