// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../libs/Const.sol";

interface IXChainAdapter {

    function swap(
        Const.TokenID _tokenId,
        uint[] memory _amounts,
        address _from,
        uint[] memory _toChainIds,
        address[] memory _toAddresses
    ) external;
}
