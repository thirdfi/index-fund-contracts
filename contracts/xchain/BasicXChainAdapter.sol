//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../../libs/Const.sol";
import "./IXChainAdapter.sol";

contract BasicXChainAdapter is IXChainAdapter,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    bytes32 public constant CLIENT_ROLE = keccak256("CLIENT_ROLE");

    // Map of message peers (chainId => peer). Because anyone can send messages, it needs to verify the sender.
    mapping(uint => address) public peers;

    function initialize() public virtual initializer {
        __Ownable_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _revokeRole(DEFAULT_ADMIN_ROLE, owner());
        super.transferOwnership(newOwner);
        _setupRole(DEFAULT_ADMIN_ROLE, newOwner);
    }

    function setPeers(uint[] memory _chainIds, address[] memory _peers) external onlyOwner {
        uint length = _chainIds.length;
        for (uint i = 0; i < length; i++) {
            uint chainId = _chainIds[i];
            require(chainId != 0, "Invalid chainID");
            peers[chainId] = _peers[i];
        }
    }

    function transfer(
        uint8 _tokenId,
        uint[] memory _amounts,
        uint[] memory _toChainIds,
        address[] memory _toAddresses
    ) external payable virtual onlyRole(CLIENT_ROLE) {
    }

    function call(
        uint _toChainId,
        address _targetContract,
        uint _targetCallValue,
        bytes memory _targetCallData
    ) external payable virtual onlyRole(CLIENT_ROLE) {
    }

    function calcTransferFee() public view virtual returns (uint) {
        return 0;
    }

    function calcCallFee(
        uint _toChainId,
        address _targetContract,
        uint _targetCallValue,
        bytes memory _targetCallData
    ) public view virtual returns (uint) {
        return 0;
    }

    receive() external payable {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
