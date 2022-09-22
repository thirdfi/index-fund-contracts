const { ethers } = require("hardhat")
const parseUnits = ethers.utils.parseUnits;
const param = require("../../parameters")

// The price of native assets in USD. The precision is 8.
const PRICE_DECIMALS = 8;
const avaxPrice = parseUnits('17', PRICE_DECIMALS);
const bnbPrice = parseUnits('266', PRICE_DECIMALS);
const ethPrice = parseUnits('1273', PRICE_DECIMALS);
const maticPrice = parseUnits('0.74', PRICE_DECIMALS);

const gasPriceOnAurora = parseUnits('0.1', 'gwei');
const gasPriceOnAvalanche = parseUnits('30', 'gwei');
const gasPriceOnBSC = parseUnits('5', 'gwei');
const gasPriceOnEthereum = parseUnits('5', 'gwei');
const gasPriceOnPolygon = parseUnits('30', 'gwei');

async function main() {
    const { chainId } = await ethers.provider.getNetwork();
    console.log(`CHAIN ID: ${chainId}`);

    const nativeAssetPrice = getNativeAssetPrice(chainId);
    const chainIds = [
        param.auroraMainnet.chainId,
        param.avaxMainnet.chainId,
        param.bscMainnet.chainId,
        param.ethMainnet.chainId,
        param.maticMainnet.chainId,
    ];
    const costs = [
        gasPriceOnAurora.mul(ethPrice).div(nativeAssetPrice),
        gasPriceOnAvalanche.mul(avaxPrice).div(nativeAssetPrice),
        gasPriceOnBSC.mul(bnbPrice).div(nativeAssetPrice),
        gasPriceOnEthereum.mul(ethPrice).div(nativeAssetPrice),
        gasPriceOnPolygon.mul(maticPrice).div(nativeAssetPrice),
    ];

    if (chainId == param.auroraMainnet.chainId
        || chainId == param.avaxMainnet.chainId
        || chainId == param.maticMainnet.chainId
    ) {
        await setGasCostsForBNI(chainIds, costs);
    }

    if (chainId == param.auroraMainnet.chainId
        || chainId == param.avaxMainnet.chainId
        || chainId == param.bscMainnet.chainId
        || chainId == param.ethMainnet.chainId
    ) {
        await setGasCostsForSTI(chainIds, costs);
    }
}

function getNativeAssetPrice(chainId) {
    switch(chainId) {
        case param.auroraMainnet.chainId:
            return ethPrice;
        case param.avaxMainnet.chainId:
            return avaxPrice;
        case param.bscMainnet.chainId:
            return bnbPrice;
        case param.ethMainnet.chainId:
            return ethPrice;
        case param.maticMainnet.chainId:
            return maticPrice;
    }
    throw `It's running on the unsupported network(${chainId})`;
}

async function setGasCostsForBNI(chainIds, costs) {
    console.log("Setting gas costs on BNIUserAgentTest");
    try {
        const BNIUserAgentTest = await ethers.getContractFactory("BNIUserAgentTest");
        const userAgentProxy = await ethers.getContract("BNIUserAgentTest_Proxy");
        const userAgent = BNIUserAgentTest.attach(userAgentProxy.address);
        const tx = await userAgent.setGasCosts(chainIds, costs);
        await tx.wait();
    } catch(e) {
        console.log(e);
    }
}

async function setGasCostsForSTI(chainIds, costs) {
    console.log("Setting gas costs on STIUserAgentTest");
    try {
        const STIUserAgentTest = await ethers.getContractFactory("STIUserAgentTest");
        const userAgentProxy = await ethers.getContract("STIUserAgentTest_Proxy");
        const userAgent = STIUserAgentTest.attach(userAgentProxy.address);
        const tx = await userAgent.setGasCosts(chainIds, costs);
        await tx.wait();
    } catch(e) {
        console.log(e);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })