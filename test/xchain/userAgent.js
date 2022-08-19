const { expect } = require("chai");
const { ethers, deployments } = require("hardhat");

describe("UserAgent", async () => {

  let userAgent;
  let userAgentArtifact;

  before(async () => {
    [deployer, a1, a2, ...accounts] = await ethers.getSigners();

    userAgentArtifact = await deployments.getArtifact("UserAgent");
  });

  beforeEach(async () => {
    await deployments.fixture(["hardhat_eth_sti"])

    const userAgentProxy = await ethers.getContract("UserAgent_Proxy");
    userAgent = new ethers.Contract(userAgentProxy.address, userAgentArtifact.abi, a1);
  });

  it('Should work correctly with EOA', async () => {
    const data = Buffer.from("TEST MESSAGE");
    const dataHash = await userAgent.getMessageHashForSafe(a1.address, data);
    const signature = await a1.signMessage(ethers.utils.arrayify(dataHash));
    expect(await userAgent.isValidSignature(a1.address, data, signature)).equal(true);
  });

  it('Should work correctly with GnosisSafe', async () => {
  });

});