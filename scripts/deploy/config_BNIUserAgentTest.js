const { ethers } = require("hardhat")
const param = require("../../parameters/testnet")

async function main() {
    console.log("Setting agents on BNIUserAgentTest")
    try {
        const BNIUserAgentTest = await ethers.getContractFactory("BNIUserAgentTest");
        const userAgentProxy = await ethers.getContract("BNIUserAgentTest_Proxy");
        const userAgent = BNIUserAgentTest.attach(userAgentProxy.address);
        const tx = await userAgent.setUserAgents([
            param.auroraTestnet.chainId,
            param.avaxTestnet.chainId,
            param.maticMumbai.chainId,
        ],[
            param.auroraTestnet.Securo.bniUserAgent,
            param.avaxTestnet.Securo.bniUserAgent,
            param.maticMumbai.Securo.bniUserAgent,
        ]);
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