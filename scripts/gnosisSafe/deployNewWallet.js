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
            break;
        case param.avaxTestnet.chainId:
            break;
        case param.bscTestnet.chainId:
            break;
        case param.ethRinkeby.chainId:
            proxyFactoryAddress = "0xE89ce3bcD35bA068A9F9d906896D3d03Ad5C30EC";
            singletonAddress = "0xb4A7C7da1631CF60A2Cf23ABc86986f99a1A7f70";
            break;
        case param.maticMumbai.chainId:
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
            ["0xd91Fbc9b431464D737E1BC4e76900D43405a639b", "0xAa5d61cE6eB431f55dE741Ea6a6ff3a1AfE4D47B", "0x401903c872A0569cdFe21f9BcDfa0f6D0a3D4D00"],
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