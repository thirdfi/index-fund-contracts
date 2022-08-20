// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

library Token {
    function changeDecimals(uint amount, uint curDecimals, uint newDecimals) internal pure returns(uint) {
        if (curDecimals == newDecimals) {
            return amount;
        } else if (curDecimals < newDecimals) {
            return amount * (10 ** (newDecimals - curDecimals));
        } else {
            return amount / (10 ** (curDecimals - newDecimals));
        }
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "ETH transfer failed");
    }

    function getChainID() internal view returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }

    function bytesToAddress(bytes memory bys) internal pure returns (address addr) {
        assembly {
            addr := mload(add(bys, 20))
        }
    }
}
