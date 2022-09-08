const { expect } = require("chai");
const { ethers, deployments } = require("hardhat");
import Safe, { SafeFactory, SafeAccountConfig } from '@gnosis.pm/safe-core-sdk'
import EthersAdapter from '@gnosis.pm/safe-ethers-lib'

describe("UserAgent", async () => {

  let userAgent;
  let userAgentArtifact;
  let deployer, a1, a2, accounts;

  before(async () => {
    [deployer, a1, a2, ...accounts] = await ethers.getSigners();

    userAgentArtifact = await deployments.getArtifact("STIUserAgent");
  });

  beforeEach(async () => {
    await deployments.fixture(["hardhat_eth_sti"])

    const userAgentProxy = await ethers.getContract("STIUserAgent_Proxy");
    userAgent = new ethers.Contract(userAgentProxy.address, userAgentArtifact.abi, a1);
  });

  describe("Test with EOA", async () => {
    it('The data should be verified correctly', async () => {
      const data = Buffer.from("TEST MESSAGE");
      const dataHash = await userAgent.getMessageHashForSafe(data);
      const signature = await a1.signMessage(ethers.utils.arrayify(dataHash));
      expect(await userAgent.isValidSignature(a1.address, data, signature)).equal(true);
    });

    it('The function should be called correctly', async () => {
      const nonce = await userAgent.nonces(a1.address);
      const data = ethers.utils.solidityKeccak256(
        ['uint', 'uint'],
        [123, nonce]
      );
      const dataHash = await userAgent.getMessageHashForSafe(data);
      const signature = await a1.signMessage(ethers.utils.arrayify(dataHash));
      // expect(await userAgent.isValidFunctionCall(a1.address, 123, nonce, signature)).equal(true);
    });
  });

  describe("Test with GnosisSafe", async () => {
    let safeSdk: Safe;
    let safeAddress;

    beforeEach(async () => {
      const ethAdapter = new EthersAdapter({
        ethers,
        signer: deployer
      })
      const safeFactory = await SafeFactory.create({ ethAdapter })
      const owners = [accounts[0].address, accounts[1].address, accounts[2].address];
      const threshold = 2;
      const safeAccountConfig: SafeAccountConfig = {
        owners,
        threshold,
      };
      safeSdk = await safeFactory.deploySafe({ safeAccountConfig })
      safeAddress = safeSdk.getAddress();
    });

    it('The data should be verified correctly', async () => {
      const data = Buffer.from("TEST MESSAGE");
      const dataHash = await userAgent.getMessageHashForSafe(data);
      const signature1 = await accounts[0].signMessage(ethers.utils.arrayify(dataHash));
      const signature2 = await accounts[1].signMessage(ethers.utils.arrayify(dataHash));
      const signatures = signature1.concat(signature2.slice(2));
      expect(await userAgent.isValidSignature(safeAddress, data, signatures)).equal(true);
    });

    it('Should be failed with incorrect signature', async () => {
      const data = Buffer.from("TEST MESSAGE");
      const dataHash = await userAgent.getMessageHashForSafe(data);
      const signature1 = await accounts[0].signMessage(ethers.utils.arrayify(dataHash));
      const signature2 = await a1.signMessage(ethers.utils.arrayify(dataHash));
      const signatures = signature1.concat(signature2.slice(2));
      expect(await userAgent.isValidSignature(safeAddress, data, signature1)).equal(false);
      expect(await userAgent.isValidSignature(safeAddress, data, signatures)).equal(false);
    });

    it('The function should be called correctly', async () => {
      const nonce = await userAgent.nonces(safeAddress);
      const data = ethers.utils.solidityKeccak256(
        ['uint', 'uint'],
        [123, nonce]
      );
      const dataHash = await userAgent.getMessageHashForSafe(data);
      const signature1 = await accounts[0].signMessage(ethers.utils.arrayify(dataHash));
      const signature2 = await accounts[1].signMessage(ethers.utils.arrayify(dataHash));
      const signatures = signature1.concat(signature2.slice(2));
      // expect(await userAgent.isValidFunctionCall(safeAddress, 123, nonce, signatures)).equal(true);
    });
  });

});