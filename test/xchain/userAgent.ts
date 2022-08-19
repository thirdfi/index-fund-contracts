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

    userAgentArtifact = await deployments.getArtifact("UserAgent");
  });

  beforeEach(async () => {
    await deployments.fixture(["hardhat_eth_sti"])

    const userAgentProxy = await ethers.getContract("UserAgent_Proxy");
    userAgent = new ethers.Contract(userAgentProxy.address, userAgentArtifact.abi, a1);
  });

  describe("Test with EOA", async () => {
    it('Should work correctly with EOA', async () => {
      const data = Buffer.from("TEST MESSAGE");
      const dataHash = await userAgent.getMessageHashForSafe(a1.address, data);
      const signature = await a1.signMessage(ethers.utils.arrayify(dataHash));
      expect(await userAgent.isValidSignature(a1.address, data, signature)).equal(true);
    });
  });

  describe("Test with GnosisSafe", async () => {
    let safeSdk: Safe;

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
    });

    it('Should work correctly with GnosisSafe', async () => {
      const safeAddress = safeSdk.getAddress();
    });
  });

});