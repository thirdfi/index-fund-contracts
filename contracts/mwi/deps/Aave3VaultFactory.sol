//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface Logic {
    function transferOwnership(address _newOwner) external;
}

contract Aave3VaultFactory is Ownable {
    UpgradeableBeacon immutable upgradeableBeacon;

    address[] public vaults;
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

    /// @param underlying is the underlying token of the Aav3 aToken
    function createVault(address underlying, bytes calldata _data) external onlyOwner returns (address _proxyAddress){
        require(underlying != address(0), "Invalid underlying");
        
        BeaconProxy proxy = new BeaconProxy(
           address(upgradeableBeacon),
            _data
        );

        _proxyAddress = address(proxy);

        Logic(_proxyAddress).transferOwnership(owner());

        vaults.push(address(proxy));
        indices[underlying] = vaults.length;
    }

    function totalVaults() external view returns (uint) {
        return vaults.length;
    }

    function getVault(uint _index) external view returns (address) {
        return vaults[_index];
    }

    function getIndex(address underlying) external view returns (uint) {
        uint index = indices[underlying];
        return (index != 0) ? index - 1 : type(uint).max;
    }

    function getVaultByUnderlying(address underlying) external view returns (address) {
        uint index = indices[underlying];
        return (index != 0) ? vaults[index-1] : address(0);
    }

}
