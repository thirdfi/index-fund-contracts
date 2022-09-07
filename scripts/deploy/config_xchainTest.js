const { ethers } = require("hardhat")
const param = require("../../parameters/testnet")

async function main() {
    console.log("Setting peers on MultichainXChainAdapterTest")
    try {
        const MultichainXChainAdapterTest = await ethers.getContractFactory("MultichainXChainAdapterTest");
        const mchainAdapterProxy = await ethers.getContract("MultichainXChainAdapterTest_Proxy");
        const mchainAdapter = MultichainXChainAdapterTest.attach(mchainAdapterProxy.address);
        const tx = await mchainAdapter.setPeers([
            param.avaxTestnet.chainId,
            param.bscTestnet.chainId,
            param.ethRinkeby.chainId,
            param.ftmTestnet.chainId,
            param.maticMumbai.chainId
        ],[
            param.avaxTestnet.Securo.mchainAdapter,
            param.bscTestnet.Securo.mchainAdapter,
            param.ethRinkeby.Securo.mchainAdapter,
            param.ftmTestnet.Securo.mchainAdapter,
            param.maticMumbai.Securo.mchainAdapter
        ]);
        await tx.wait();
    } catch(e) {
        console.log(e);
    }

    console.log("Setting peers on CBridgeXChainAdapterTest")
    try {
        const CBridgeXChainAdapterTest = await ethers.getContractFactory("CBridgeXChainAdapterTest");
        const cbridgeAdapterProxy = await ethers.getContract("CBridgeXChainAdapterTest_Proxy");
        const cbridgeAdapter = CBridgeXChainAdapterTest.attach(cbridgeAdapterProxy.address);
        const tx = await cbridgeAdapter.setPeers([
            param.auroraTestnet.chainId,
            param.avaxTestnet.chainId,
            param.bscTestnet.chainId,
            param.ethRinkeby.chainId,
            param.ftmTestnet.chainId,
            param.maticMumbai.chainId
          ],[
            param.auroraTestnet.Securo.cbridgeAdapter,
            param.avaxTestnet.Securo.cbridgeAdapter,
            param.bscTestnet.Securo.cbridgeAdapter,
            param.ethRinkeby.Securo.cbridgeAdapter,
            param.ftmTestnet.Securo.cbridgeAdapter,
            param.maticMumbai.Securo.cbridgeAdapter
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