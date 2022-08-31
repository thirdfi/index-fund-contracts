//SPDX-License-Identifier: MIT
pragma solidity  0.8.9;

import "../../../libs/Const.sol";
import "../../../libs/Token.sol";
import "../../bni/constant/AvaxConstant.sol";
import "../../bni/constant/BscConstant.sol";
import "../../bni/constant/EthConstant.sol";
import "../../bni/constant/MaticConstant.sol";

// https://bridgeapi.anyswap.exchange/v3/serverinfoV3?chainId=all&version=STABLEV3
library AnyswapMap {

    struct Entry{
        address router;
        address underlying;
        address anyToken;
        uint8 underlyingDecimals;
        uint8 anyTokenDecimals;
        uint minimumSwap;
    }

    function initMap(mapping(address => mapping(uint => AnyswapMap.Entry)) storage _map) internal {
        address USDT = Token.getTokenAddress(Const.TokenID.USDT);
        _map[USDT][AvaxConstant.CHAINID] = Entry({
            router: 0xB0731d50C681C45856BFc3f7539D5f61d4bE81D8,
            underlying: AvaxConstant.USDT,
            anyToken: 0x94977c9888F3D2FAfae290d33fAB4a5a598AD764,
            underlyingDecimals: 6,
            anyTokenDecimals: 6,
            minimumSwap: 12
        });
        _map[USDT][BscConstant.CHAINID] = Entry({
            router: 0xd1C5966f9F5Ee6881Ff6b261BBeDa45972B1B5f3,
            underlying: BscConstant.USDT,
            anyToken: 0xEDF0c420bc3b92B961C6eC411cc810CA81F5F21a,
            underlyingDecimals: 18,
            anyTokenDecimals: 18,
            minimumSwap: 12
        });
        _map[USDT][EthConstant.CHAINID] = Entry({
            router: 0x6b7a87899490EcE95443e979cA9485CBE7E71522,
            underlying: EthConstant.USDT,
            anyToken: 0x22648C12acD87912EA1710357B1302c6a4154Ebc,
            underlyingDecimals: 6,
            anyTokenDecimals: 6,
            minimumSwap: 45
        });
        _map[USDT][MaticConstant.CHAINID] = Entry({
            router: 0x4f3Aff3A747fCADe12598081e80c6605A8be192F,
            underlying: MaticConstant.USDT,
            anyToken: 0xE3eeDa11f06a656FcAee19de663E84C7e61d3Cac,
            underlyingDecimals: 6,
            anyTokenDecimals: 6,
            minimumSwap: 12
        });

        address USDC = Token.getTokenAddress(Const.TokenID.USDC);
        _map[USDC][AvaxConstant.CHAINID] = Entry({
            router: 0xB0731d50C681C45856BFc3f7539D5f61d4bE81D8,
            underlying: AvaxConstant.USDC,
            anyToken: 0xcc9b1F919282c255eB9AD2C0757E8036165e0cAd,
            underlyingDecimals: 6,
            anyTokenDecimals: 6,
            minimumSwap: 12
        });
        _map[USDC][BscConstant.CHAINID] = Entry({
            router: 0xd1C5966f9F5Ee6881Ff6b261BBeDa45972B1B5f3,
            underlying: BscConstant.USDC,
            anyToken: 0x8965349fb649A33a30cbFDa057D8eC2C48AbE2A2,
            underlyingDecimals: 18,
            anyTokenDecimals: 18,
            minimumSwap: 12
        });
        _map[USDC][EthConstant.CHAINID] = Entry({
            router: 0x6b7a87899490EcE95443e979cA9485CBE7E71522,
            underlying: EthConstant.USDC,
            anyToken: 0x7EA2be2df7BA6E54B1A9C70676f668455E329d29,
            underlyingDecimals: 6,
            anyTokenDecimals: 6,
            minimumSwap: 45
        });
        _map[USDC][MaticConstant.CHAINID] = Entry({
            router: 0x4f3Aff3A747fCADe12598081e80c6605A8be192F,
            underlying: MaticConstant.USDC,
            anyToken: 0xd69b31c3225728CC57ddaf9be532a4ee1620Be51,
            underlyingDecimals: 6,
            anyTokenDecimals: 6,
            minimumSwap: 12
        });
    }
}
