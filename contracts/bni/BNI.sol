// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract BNI is ERC20Upgradeable, OwnableUpgradeable {

  address private _minter;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() external initializer {
    __Ownable_init();
    __ERC20_init("Blockchain Network Index", "BNI");
  }

  modifier onlyMinter() {
    require(_minter == msg.sender, "Mintable: caller is not the minter");
    _;
  }

  function setMinter( address minter_ ) external onlyOwner() returns ( bool ) {
    _minter = minter_;
    return true;
  }

  function minter() public view returns (address) {
    return _minter;
  }

  function mint(address account_, uint256 amount_) external onlyMinter() {
    _mint(account_, amount_);
  }

  function burn(uint256 amount) public virtual {
    _burn(msg.sender, amount);
  }

  function burnFrom(address account, uint256 amount) public virtual {
    if (msg.sender != _minter) {
      _spendAllowance(account, msg.sender, amount);
    }
    _burn(account, amount);
  }
}
