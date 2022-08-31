const { ethers } = require("hardhat")
const param = require("../../parameters")

async function main() {
    console.log("Setting agents on BNIUserAgent")
    try {
        const BNIUserAgent = await ethers.getContractFactory("BNIUserAgent");
        const userAgentProxy = await ethers.getContract("BNIUserAgent_Proxy");
        const userAgent = BNIUserAgent.attach(userAgentProxy.address);
        const tx = await userAgent.setUserAgents([
            param.auroraMainnet.chainId,
            param.avaxMainnet.chainId,
            param.maticMainnet.chainId,
        ],[
            param.auroraMainnet.Securo.bniUserAgent,
            param.avaxMainnet.Securo.bniUserAgent,
            param.maticMainnet.Securo.bniUserAgent,
        ]);
        tx.wait();
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