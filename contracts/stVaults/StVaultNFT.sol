//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import "../../interfaces/IStVaultNFT.sol";

contract StVaultNFT is IStVaultNFT,
    ERC721Upgradeable,
    OwnableUpgradeable
{
    address public stVault;
    uint256 public tokenIdIndex;

    modifier isStVault() {
        require(msg.sender == stVault, "Caller is not stVault contract");
        _;
    }

    function initialize(
        string memory _name, string memory _symbol, address _stVault
    ) public initializer {
        __Ownable_init_unchained();
        __ERC721_init_unchained(_name, _symbol);

        stVault = _stVault;
    }

    /**
     * @dev Increments the token supply and mints the token based on that index
     * @param _to - Address that will be the owner of minted token
     * @return Index of the minted token
     */
    function mint(address _to) external override isStVault returns (uint256) {
        uint256 currentIndex = tokenIdIndex;
        currentIndex++;

        _mint(_to, currentIndex);

        tokenIdIndex = currentIndex;

        return currentIndex;
    }

    /**
     * @dev Burn the token with specified _tokenId
     * @param _tokenId - Id of the token that will be burned
     */
    function burn(uint256 _tokenId) external override isStVault {
        _burn(_tokenId);
    }

    function isApprovedOrOwner(address _spender, uint _tokenId) external view returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    /**
     * @dev Set stVault contract address
     * @param _stVault - address of the stVault contract
     */
    function setStVault(address _stVault) external override onlyOwner {
        stVault = _stVault;
    }
}
