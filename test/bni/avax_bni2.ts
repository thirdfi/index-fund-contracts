const { expect } = require("chai");
const { ethers, deployments } = require("hardhat");
import Safe, { SafeFactory, SafeAccountConfig } from '@gnosis.pm/safe-core-sdk'
import EthersAdapter from '@gnosis.pm/safe-ethers-lib'
const { BigNumber } = ethers;
const AddressZero = ethers.constants.AddressZero;

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable.json").abi;
const param = require("../../parameters");
const { avaxMainnet: network_ } = require("../../parameters");

function getUsdt6Amount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}

function getAuroraUsdtAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}
function getAvaxUsdtAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}
function getMaticUsdtAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}

const CBridge = 0;
const Multichain = 1;

describe("BNI non-custodial on Avalanche", async () => {

  let userAgent, minter, vault, usdt;
  let minterArtifact, vaultArtifact, userAgentArtifact;
  let deployer, admin, a1, accounts;
  var ret, data, dataHash, signature, nonce, pool, usdt6Amt;

  before(async () => {
    [deployer, admin, a1, ...accounts] = await ethers.getSigners();

    minterArtifact = await deployments.getArtifact("BNIMinter");
    vaultArtifact = await deployments.getArtifact("BNIVault");
    userAgentArtifact = await deployments.getArtifact("BNIUserAgent");
  });

  beforeEach(async () => {
    await deployments.fixture(["hardhat_avax_bni"])

    const userAgentProxy = await ethers.getContract("BNIUserAgent_Proxy");
    userAgent = new ethers.Contract(userAgentProxy.address, userAgentArtifact.abi, a1);
    const minterProxy = await ethers.getContract("BNIMinter_Proxy");
    minter = new ethers.Contract(minterProxy.address, minterArtifact.abi, a1);
    const vaultProxy = await ethers.getContract("BNIVault_Proxy");
    vault = new ethers.Contract(vaultProxy.address, vaultArtifact.abi, a1);

    await minter.connect(deployer).initialize2(userAgentProxy.address, AddressZero);
    await vault.connect(deployer).initialize2(userAgentProxy.address, AddressZero);
    await userAgent.connect(deployer).setAdmin(admin.address);

    usdt = new ethers.Contract(network_.Swap.USDT, ERC20_ABI, deployer);
  });

  describe('Basic', () => {
    it("Should be set by only owner", async () => {
      await expect(userAgent.setAdmin(admin.address)).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(userAgent.setUserAgents([],[])).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should be failed if no user agent for target blockchain", async () => {
      const toChainIds = [
        param.auroraMainnet.chainId,
        param.avaxMainnet.chainId,
        param.maticMainnet.chainId,
      ];
      const amounts = [
        getAuroraUsdtAmount('10000'),
        getAvaxUsdtAmount('10000'),
        getMaticUsdtAmount('10000'),
      ];
      const adapterTypes = [
        CBridge,
        Multichain,
        Multichain,
      ]

      nonce = await userAgent.nonces(a1.address);
      data = ethers.utils.solidityKeccak256(
        ['address', 'uint', 'uint[]', 'uint[]', 'uint8[]'],
        [a1.address, nonce, amounts, toChainIds, adapterTypes]
      );
      dataHash = await userAgent.getMessageHashForSafe(data);
      signature = await admin.signMessage(ethers.utils.arrayify(dataHash));
      await userAgent.connect(deployer).setAdmin(admin.address);
      await expect(userAgent.transfer(amounts, toChainIds, adapterTypes, signature)).to.be.revertedWith("Invalid user agent");
    });
  });

  describe('Test with EOA', () => {
    beforeEach(async () => {
      await userAgent.connect(deployer).setUserAgents([
        param.auroraMainnet.chainId, param.maticMainnet.chainId
      ],[
        accounts[0].address, accounts[1].address // It uses any addresses for test
      ])
    });

    it("Deposit", async () => {
      await usdt.transfer(a1.address, getAvaxUsdtAmount('30000'));
      await usdt.connect(a1).approve(userAgent.address, getAvaxUsdtAmount('30000'));

      // Init a deposit flow
      usdt6Amt = getUsdt6Amount('30000');
      pool = await vault.getAllPoolInUSD();
      nonce = await userAgent.nonces(a1.address);
      data = ethers.utils.solidityKeccak256(
        ['address', 'uint', 'uint', 'uint'],
        [a1.address, nonce, pool, usdt6Amt]
      );
      dataHash = await userAgent.getMessageHashForSafe(data);
      signature = await admin.signMessage(ethers.utils.arrayify(dataHash));
      await expect(userAgent.initDeposit(pool, usdt6Amt, await a1.signMessage(ethers.utils.arrayify(dataHash)))).to.be.revertedWith('Invalid signature');
      await userAgent.initDeposit(pool, usdt6Amt, signature);

      expect(await userAgent.nonces(a1.address)).equal(1); // It should be increased
      expect(await minter.getNonce()).equal(1);
      expect(await minter.userLastOperationNonce(a1.address)).equal(1);
      ret = await minter.getOperation(1);
      expect(ret[0]).equal(a1.address);
      expect(ret[1]).equal(1);
      expect(ret[2]).equal(pool);
      expect(ret[3]).equal(getUsdt6Amount('30000'));
      expect(ret[4]).equal(false);

      // Transfer USDT tokens to user agents on target networks
      const toChainIds = [
        param.auroraMainnet.chainId,
        param.avaxMainnet.chainId,
        param.maticMainnet.chainId,
      ];
      const amounts = [
        getAuroraUsdtAmount('10000'),
        getAvaxUsdtAmount('10000'),
        getMaticUsdtAmount('10000'),
      ];
      const adapterTypes = [
        CBridge,
        Multichain,
        Multichain,
      ]

      nonce = await userAgent.nonces(a1.address);
      data = ethers.utils.solidityKeccak256(
        ['address', 'uint', 'uint[]', 'uint[]', 'uint8[]'],
        [a1.address, nonce, amounts, toChainIds, adapterTypes]
      );
      dataHash = await userAgent.getMessageHashForSafe(data);
      signature = await admin.signMessage(ethers.utils.arrayify(dataHash));
      await expect(userAgent.transfer(amounts, toChainIds, adapterTypes, await a1.signMessage(ethers.utils.arrayify(dataHash)))).to.be.revertedWith('Invalid signature');
      await userAgent.transfer(amounts, toChainIds, adapterTypes, signature);
      expect(await usdt.balanceOf(a1.address)).equal(0);
    });
  });

  // describe("Test with GnosisSafe", async () => {
  //   let safeSdk: Safe;
  //   let safeAddress;

  //   beforeEach(async () => {
  //     const ethAdapter = new EthersAdapter({
  //       ethers,
  //       signer: deployer
  //     })
  //     const safeFactory = await SafeFactory.create({ ethAdapter })
  //     const owners = [accounts[0].address, accounts[1].address, accounts[2].address];
  //     const threshold = 2;
  //     const safeAccountConfig: SafeAccountConfig = {
  //       owners,
  //       threshold,
  //     };
  //     safeSdk = await safeFactory.deploySafe({ safeAccountConfig })
  //     safeAddress = safeSdk.getAddress();
  //   });

  //   it('The data should be verified correctly', async () => {
  //     const data = Buffer.from("TEST MESSAGE");
  //     const dataHash = await userAgent.getMessageHashForSafe(data);
  //     const signature1 = await accounts[0].signMessage(ethers.utils.arrayify(dataHash));
  //     const signature2 = await accounts[1].signMessage(ethers.utils.arrayify(dataHash));
  //     const signatures = signature1.concat(signature2.slice(2));
  //     expect(await userAgent.isValidSignature(safeAddress, data, signatures)).equal(true);
  //   });

  //   it('Should be failed with incorrect signature', async () => {
  //     const data = Buffer.from("TEST MESSAGE");
  //     const dataHash = await userAgent.getMessageHashForSafe(data);
  //     const signature1 = await accounts[0].signMessage(ethers.utils.arrayify(dataHash));
  //     const signature2 = await a1.signMessage(ethers.utils.arrayify(dataHash));
  //     const signatures = signature1.concat(signature2.slice(2));
  //     expect(await userAgent.isValidSignature(safeAddress, data, signature1)).equal(false);
  //     expect(await userAgent.isValidSignature(safeAddress, data, signatures)).equal(false);
  //   });

  //   it('The function should be called correctly', async () => {
  //     const nonce = await userAgent.nonces(safeAddress);
  //     const data = ethers.utils.solidityKeccak256(
  //       ['uint', 'uint'],
  //       [123, nonce]
  //     );
  //     const dataHash = await userAgent.getMessageHashForSafe(data);
  //     const signature1 = await accounts[0].signMessage(ethers.utils.arrayify(dataHash));
  //     const signature2 = await accounts[1].signMessage(ethers.utils.arrayify(dataHash));
  //     const signatures = signature1.concat(signature2.slice(2));
  //     expect(await userAgent.isValidFunctionCall(safeAddress, 123, nonce, signatures)).equal(true);
  //   });
  // });

});