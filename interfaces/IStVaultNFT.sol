// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

interface IStVaultNFT is IERC721Upgradeable {

    function mint(address _to) external returns (uint);
    function burn(uint _tokenId) external;

    function setStVault(address _stVault) external;
}