// SPDX-License-Identifier: GPL-3.0-only
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract MessageBusAddress is OwnableUpgradeable {
    event MessageBusUpdated(address messageBus);

    address public messageBus;

    function __MessageBusAddress_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function setMessageBus(address _messageBus) public onlyOwner {
        messageBus = _messageBus;
        emit MessageBusUpdated(messageBus);
    }
}
