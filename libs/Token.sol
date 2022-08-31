// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../contracts/bni/constant/AuroraConstant.sol";
import "../contracts/bni/constant/AuroraConstantTest.sol";
import "../contracts/bni/constant/AvaxConstant.sol";
import "../contracts/bni/constant/AvaxConstantTest.sol";
import "../contracts/bni/constant/BscConstant.sol";
import "../contracts/bni/constant/BscConstantTest.sol";
import "../contracts/bni/constant/EthConstant.sol";
import "../contracts/bni/constant/EthConstantTest.sol";
import "../contracts/bni/constant/FtmConstantTest.sol";
import "../contracts/bni/constant/MaticConstant.sol";
import "../contracts/bni/constant/MaticConstantTest.sol";
import "./Const.sol";

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

    function getTokenAddress(Const.TokenID _tokenId) internal view returns (address) {
        uint chainId = getChainID();
        if (chainId == AuroraConstant.CHAINID) {
            if (_tokenId == Const.TokenID.USDC) return AuroraConstant.USDC;
            else if (_tokenId == Const.TokenID.USDT) return AuroraConstant.USDT;
        } else if (chainId == AvaxConstant.CHAINID) {
            if (_tokenId == Const.TokenID.USDC) return AvaxConstant.USDC;
            else if (_tokenId == Const.TokenID.USDT) return AvaxConstant.USDT;
        } else if (chainId == BscConstant.CHAINID) {
            if (_tokenId == Const.TokenID.USDC) return BscConstant.USDC;
            else if (_tokenId == Const.TokenID.USDT) return BscConstant.USDT;
        } else if (chainId == EthConstant.CHAINID) {
            if (_tokenId == Const.TokenID.USDC) return EthConstant.USDC;
            else if (_tokenId == Const.TokenID.USDT) return EthConstant.USDT;
        } else if (chainId == MaticConstant.CHAINID) {
            if (_tokenId == Const.TokenID.USDC) return MaticConstant.USDC;
            else if (_tokenId == Const.TokenID.USDT) return MaticConstant.USDT;
        }
        return address(0);
    }

    function getTestTokenAddress(Const.TokenID _tokenId) internal view returns (address) {
        uint chainId = getChainID();
        if (chainId == AuroraConstantTest.CHAINID) {
            if (_tokenId == Const.TokenID.USDC) return AuroraConstantTest.USDC;
            else if (_tokenId == Const.TokenID.USDT) return AuroraConstantTest.USDT;
        } else if (chainId == AvaxConstantTest.CHAINID) {
            if (_tokenId == Const.TokenID.USDC) return AvaxConstantTest.USDC;
            else if (_tokenId == Const.TokenID.USDT) return AvaxConstantTest.USDT;
        } else if (chainId == BscConstantTest.CHAINID) {
            if (_tokenId == Const.TokenID.USDC) return BscConstantTest.USDC;
            else if (_tokenId == Const.TokenID.USDT) return BscConstantTest.USDT;
        } else if (chainId == EthConstantTest.CHAINID) {
            if (_tokenId == Const.TokenID.USDC) return EthConstantTest.USDC;
            else if (_tokenId == Const.TokenID.USDT) return EthConstantTest.USDT;
        } else if (chainId == FtmConstantTest.CHAINID) {
            if (_tokenId == Const.TokenID.USDC) return FtmConstantTest.USDC;
            else if (_tokenId == Const.TokenID.USDT) return FtmConstantTest.USDT;
        } else if (chainId == MaticConstantTest.CHAINID) {
            if (_tokenId == Const.TokenID.USDC) return MaticConstantTest.USDC;
            else if (_tokenId == Const.TokenID.USDT) return MaticConstantTest.USDT;
        }
        return address(0);
    }
}
