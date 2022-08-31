const { ethers } = require("hardhat")
const param = require("../../parameters")

async function main() {
    console.log("Setting peers on MultichainXChainAdapter")
    try {
        const MultichainXChainAdapter = await ethers.getContractFactory("MultichainXChainAdapter");
        const mchainAdapterProxy = await ethers.getContract("MultichainXChainAdapter_Proxy");
        const mchainAdapter = MultichainXChainAdapter.attach(mchainAdapterProxy.address);
        const tx = await mchainAdapter.setPeers([
            param.avaxMainnet.chainId,
            param.bscMainnet.chainId,
            param.ethMainnet.chainId,
            param.maticMainnet.chainId
        ],[
            param.avaxMainnet.Securo.mchainAdapter,
            param.bscMainnet.Securo.mchainAdapter,
            param.ethMainnet.Securo.mchainAdapter,
            param.maticMainnet.Securo.mchainAdapter
        ]);
        tx.wait();
    } catch(e) {
        console.log(e);
    }

    console.log("Setting peers on CBridgeXChainAdapter")
    try {
        const CBridgeXChainAdapter = await ethers.getContractFactory("CBridgeXChainAdapter");
        const cbridgeAdapterProxy = await ethers.getContract("CBridgeXChainAdapter_Proxy");
        const cbridgeAdapter = CBridgeXChainAdapter.attach(cbridgeAdapterProxy.address);
        const tx = await cbridgeAdapter.setPeers([
            param.auroraMainnet.chainId,
            param.avaxMainnet.chainId,
            param.bscMainnet.chainId,
            param.ethMainnet.chainId,
            param.maticMainnet.chainId
          ],[
            param.auroraMainnet.Securo.cbridgeAdapter,
            param.avaxMainnet.Securo.cbridgeAdapter,
            param.bscMainnet.Securo.cbridgeAdapter,
            param.ethMainnet.Securo.cbridgeAdapter,
            param.maticMainnet.Securo.cbridgeAdapter
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