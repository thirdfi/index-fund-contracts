const { ethers } = require("hardhat")
const param = require("../../parameters/testnet")

async function main() {
    console.log("Setting agents on STIUserAgentTest")
    try {
        const STIUserAgentTest = await ethers.getContractFactory("STIUserAgentTest");
        const userAgentProxy = await ethers.getContract("STIUserAgentTest_Proxy");
        const userAgent = STIUserAgentTest.attach(userAgentProxy.address);
        const tx = await userAgent.setUserAgents([
            param.auroraTestnet.chainId,
            param.avaxTestnet.chainId,
            param.bscTestnet.chainId,
            param.ethRinkeby.chainId,
        ],[
            param.auroraTestnet.Securo.stiUserAgent,
            param.avaxTestnet.Securo.stiUserAgent,
            param.bscTestnet.Securo.stiUserAgent,
            param.ethRinkeby.Securo.stiUserAgent,
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