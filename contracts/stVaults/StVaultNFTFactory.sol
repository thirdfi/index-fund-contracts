//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface Logic {
    function transferOwnership(address _newOwner) external;
}

contract StVaultNFTFactory is Ownable {
    UpgradeableBeacon immutable upgradeableBeacon;

    address[] public nfts;
    mapping(address=>uint) private indices;

    constructor(address _logic) {
        upgradeableBeacon = new UpgradeableBeacon(_logic);
    }

    function getBeacon() external view returns (address) {
        return address(upgradeableBeacon);
    }

    function updateLogic(address _newImpl) onlyOwner public{
        upgradeableBeacon.upgradeTo(_newImpl);
    }

    /// @param vault is the StVault address
    function createNFT(address vault, bytes calldata _data) external onlyOwner returns (address _proxyAddress){
        require(vault != address(0), "Invalid vault");
        
        BeaconProxy proxy = new BeaconProxy(
           address(upgradeableBeacon),
            _data
        );

        _proxyAddress = address(proxy);

        Logic(_proxyAddress).transferOwnership(owner());

        nfts.push(address(proxy));
        indices[vault] = nfts.length;
    }

    function totalNFTs() external view returns (uint) {
        return nfts.length;
    }

    function getNFT(uint _index) external view returns (address) {
        return nfts[_index];
    }

    function getIndex(address vault) external view returns (uint) {
        uint index = indices[vault];
        return (index != 0) ? index - 1 : type(uint).max;
    }

    function getNFTByVault(address vault) external view returns (address) {
        uint index = indices[vault];
        return (index != 0) ? nfts[index-1] : address(0);
    }

}
