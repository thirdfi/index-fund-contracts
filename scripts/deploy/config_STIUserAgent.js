const { ethers } = require("hardhat")
const param = require("../../parameters")

async function main() {
    console.log("Setting agents on STIUserAgent")
    try {
        const STIUserAgent = await ethers.getContractFactory("STIUserAgent");
        const userAgentProxy = await ethers.getContract("STIUserAgent_Proxy");
        const userAgent = STIUserAgent.attach(userAgentProxy.address);
        const tx = await userAgent.setUserAgents([
            param.auroraMainnet.chainId,
            param.avaxMainnet.chainId,
            param.bscMainnet.chainId,
            param.ethMainnet.chainId,
        ],[
            param.auroraMainnet.Securo.stiUserAgent,
            param.avaxMainnet.Securo.stiUserAgent,
            param.bscMainnet.Securo.stiUserAgent,
            param.ethMainnet.Securo.stiUserAgent,
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