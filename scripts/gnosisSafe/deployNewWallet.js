const { ethers } = require("hardhat")
const AddressZero = ethers.constants.AddressZero;
const GnosisSafeProxyFactory_ABI = require("@gnosis.pm/safe-contracts/build/artifacts/contracts/proxies/GnosisSafeProxyFactory.sol/GnosisSafeProxyFactory").abi;
const GnosisSafe_ABI = require("@gnosis.pm/safe-contracts/build/artifacts/contracts/GnosisSafe.sol/GnosisSafe").abi;
const param = require("../../parameters/testnet")

async function getGnosisContractAddresses() {
    const [deployer] = await ethers.getSigners();
    const network = await deployer.provider.getNetwork();
    const chainId = network.chainId;

    var proxyFactoryAddress = AddressZero;
    var singletonAddress = AddressZero;
    switch(chainId) {
        case param.auroraTestnet.chainId:
            proxyFactoryAddress = "0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2";
            singletonAddress = "0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552";
            break;
        case param.avaxTestnet.chainId:
            proxyFactoryAddress = "0xc0575528B0c8B7f324Ea883938a5449B07180d85";
            singletonAddress = "0x23c472533Ba58E693a74157E25aB3738f8dAa0A0";
            break;
        case param.bscTestnet.chainId:
            proxyFactoryAddress = "0xc0575528B0c8B7f324Ea883938a5449B07180d85";
            singletonAddress = "0x23c472533Ba58E693a74157E25aB3738f8dAa0A0";
            break;
        case param.ethRinkeby.chainId:
            proxyFactoryAddress = "0xE89ce3bcD35bA068A9F9d906896D3d03Ad5C30EC";
            singletonAddress = "0xb4A7C7da1631CF60A2Cf23ABc86986f99a1A7f70";
            break;
        case param.ftmTestnet.chainId:
            proxyFactoryAddress = "0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2";
            singletonAddress = "0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552";
            break;
        case param.maticMumbai.chainId:
            proxyFactoryAddress = "0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2";
            singletonAddress = "0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552";
            break;
    }

    return {proxyFactoryAddress, singletonAddress}
}

async function main() {
    const [deployer] = await ethers.getSigners();
    var proxyFactoryAddress;
    var singletonAddress;

    try {
        const ret = await getGnosisContractAddresses();
        proxyFactoryAddress = ret.proxyFactoryAddress;
        singletonAddress = ret.singletonAddress;
        if (proxyFactoryAddress === AddressZero || singletonAddress === AddressZero) {
            console.error('Unsupported network');
            return;
        }
    } catch(e) {
        console.error(e);
        return;
    }

    console.log("Deploying a new GnosisSafe wallet")
    try {
        const proxyFactory = new ethers.Contract(proxyFactoryAddress, GnosisSafeProxyFactory_ABI, deployer);

        const gnosisIface = new ethers.utils.Interface(JSON.stringify(GnosisSafe_ABI));
        const data = gnosisIface.encodeFunctionData("setup", [
            ["0x62175fcdDa98Ca9183227dB9aBC8B3EebeA9A001", "0xa31FE6E94e0e142996A6c27EFefc2D3b4Ea31702", "0x9e79AE642261aF835f2Dc16D74D4926e64D80aA8"],
            2,
            AddressZero,
            "0x",
            AddressZero,
            AddressZero,
            0,
            AddressZero,
        ]);

        const tx = await proxyFactory.createProxyWithNonce(singletonAddress, data, Date.now());
        const receipt = await tx.wait();
        // const receipt = await deployer.provider.getTransactionReceipt(tx.hash);
        const event = receipt.events.find(event => event.event === 'ProxyCreation');
        const [proxy, singleton] = event.args;
        console.log(`==> New GnosisSafe wallet address: ${proxy}`);
    } catch(e) {
        console.error(e);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })