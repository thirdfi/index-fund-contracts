//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../BasicXChainAdapter.sol";
import "./AnyswapMap.sol";
import "./IAnyswapV6Router.sol";

contract MultichainXChainAdapter is BasicXChainAdapter{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Map of anyswap entries (tokenId => chainId => entry)
    mapping(Const.TokenID => mapping(uint => AnyswapMap.Entry)) public anyswapMap;

    function initialize() public virtual override initializer {
        super.initialize();

        AnyswapMap.initMap(anyswapMap);
        
        uint chainId = Token.getChainID();
        AnyswapMap.Entry memory entry;
        entry = anyswapMap[Const.TokenID.USDT][chainId];
        IERC20Upgradeable(entry.underlying).safeApprove(entry.router, type(uint).max);
        entry = anyswapMap[Const.TokenID.USDC][chainId];
        IERC20Upgradeable(entry.underlying).safeApprove(entry.router, type(uint).max);
    }

    function setMapEntry(
        Const.TokenID _tokenId, uint _chainId,
        address _router, address _unterlying, address _anyToken,
        uint8 _underlyingDecimals, uint8 _anyTokenDecimals, uint _minimumSwap
    ) external onlyOwner {
        anyswapMap[_tokenId][_chainId] = AnyswapMap.Entry({
            router: _router,
            underlying: _unterlying,
            anyToken: _anyToken,
            underlyingDecimals: _underlyingDecimals,
            anyTokenDecimals: _anyTokenDecimals,
            minimumSwap: _minimumSwap
        });
        if (IERC20Upgradeable(_unterlying).allowance(address(this), address(_router)) == 0) {
            IERC20Upgradeable(_unterlying).safeApprove(_router, type(uint).max);
        }
    }

    function _swap(
        Const.TokenID _tokenId,
        uint _amount,
        uint _chainId,
        uint _toChainId,
        address _to
    ) internal {
        AnyswapMap.Entry memory entry = anyswapMap[_tokenId][_chainId];
        require(_amount >= (anyswapMap[_tokenId][_toChainId].minimumSwap * (10 ** entry.underlyingDecimals)), "Too small amount");

        IAnyswapV6Router(entry.router).anySwapOutUnderlying(entry.anyToken, _to, _amount, _toChainId);
    }

    function swap(
        Const.TokenID _tokenId,
        uint[] memory _amounts,
        address _from,
        uint[] memory _toChainIds,
        address[] memory _toAddresses
    ) external onlyRole(CLIENT_ROLE) {
        uint count = _amounts.length;
        uint chainId = Token.getChainID();

        uint amount;
        for (uint i = 0; i < count; i++) {
            amount += _amounts[i];
        }
        IERC20Upgradeable(anyswapMap[_tokenId][chainId].underlying).safeTransferFrom(_from, address(this), amount);

        for (uint i = 0; i < count; i++) {
            _swap(_tokenId, _amounts[i], chainId, _toChainIds[i], _toAddresses[i]);
        }
    }
}
