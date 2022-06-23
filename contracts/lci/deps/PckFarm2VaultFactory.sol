//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface Logic {
    function transferOwnership(address _newOwner) external;
}

contract PckFarm2VaultFactory is Ownable {
    UpgradeableBeacon immutable upgradeableBeacon;

    address[] public vaults;
    mapping(uint=>uint) private indices;

    constructor(address _logic) {
        upgradeableBeacon = new UpgradeableBeacon(_logic);
    }

    function getBeacon() external view returns (address) {
        return address(upgradeableBeacon);
    }

    function updateLogic(address _newImpl) onlyOwner public{
        upgradeableBeacon.upgradeTo(_newImpl);
    }

    /// @param pid is the pool id in PancakeSwap MasterChef2
    function createVault(uint pid, bytes calldata _data) external onlyOwner returns (address _proxyAddress){
        
        BeaconProxy proxy = new BeaconProxy(
           address(upgradeableBeacon),
            _data
        );

        _proxyAddress = address(proxy);

        Logic(_proxyAddress).transferOwnership(owner());

        vaults.push(address(proxy));
        indices[pid] = vaults.length;
    }

    function totalVaults() external view returns (uint) {
        return vaults.length;
    }

    function getVault(uint _index) external view returns (address) {
        return vaults[_index];
    }

    function getIndex(uint pid) external view returns (uint) {
        uint index = indices[pid];
        return (index != 0) ? index - 1 : type(uint).max;
    }

    function getVaultByPid(uint pid) external view returns (address) {
        uint index = indices[pid];
        return (index != 0) ? vaults[index-1] : address(0);
    }

}

