//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface Logic {
    function transferOwnership(address _newOwner) external;
}

contract BscVaultFactory is Ownable {
    UpgradeableBeacon immutable upgradeableBeacon;

    address[] public vaults;

    constructor(address _logic) {
        upgradeableBeacon = new UpgradeableBeacon(_logic);
    }

    function getBeacon() external view returns (address) {
        return address(upgradeableBeacon);
    }

    function updateLogic(address _newImpl) onlyOwner public{
        upgradeableBeacon.upgradeTo(_newImpl);
    }

    function createVault(bytes calldata _data) external onlyOwner returns (address _proxyAddress){
        
        BeaconProxy proxy = new BeaconProxy(
           address(upgradeableBeacon),
            _data
        );

        _proxyAddress = address(proxy);

        Logic(_proxyAddress).transferOwnership(owner());

        vaults.push(address(proxy));
    }

    function getVault(uint _index) external view returns (address) {
        return vaults[_index];
    }

    function totalVaults() external view returns (uint) {
        return vaults.length;
    }

}

