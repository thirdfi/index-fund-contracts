const { expect } = require("chai");
const { assert, ethers, deployments } = require("hardhat");
const { expectRevert } = require('@openzeppelin/test-helpers');
const { BigNumber } = ethers;
const parseEther = ethers.utils.parseEther;
const { increaseTime } = require("../../scripts/utils/ethereum");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable.json").abi;

const { common, cndlMainnet: network_ } = require("../../parameters");

const DAY = 24 * 3600;

function getUsdtAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}

describe("BNI on Candle", async () => {

    let vault, strategy, priceOracle, usdt;
    let vaultArtifact, strategyArtifact, l2VaultArtifact;
    let admin;

    before(async () => {
      [deployer, a1, a2, ...accounts] = await ethers.getSigners();

      vaultArtifact = await deployments.getArtifact("BNIVault");
      strategyArtifact = await deployments.getArtifact("CndlBNIStrategy");
      priceOracleArtifact = await deployments.getArtifact("CndlPriceOracle");
      l2VaultArtifact = await deployments.getArtifact("CndlAave3Vault");
    });

    beforeEach(async () => {
      await deployments.fixture(["hardhat_cndl_bni"])

      const vaultProxy = await ethers.getContract("BNIVault_Proxy");
      vault = new ethers.Contract(vaultProxy.address, vaultArtifact.abi, a1);
      const strategyProxy = await ethers.getContract("CndlBNIStrategy_Proxy");
      strategy = new ethers.Contract(strategyProxy.address, strategyArtifact.abi, a1);
      const priceOracleProxy = await ethers.getContract("CndlPriceOracle_Proxy");
      priceOracle = new ethers.Contract(priceOracleProxy.address, priceOracleArtifact.abi, a1);

      admin = await ethers.getSigner(common.admin);

      usdt = new ethers.Contract(network_.Swap.USDT, ERC20_ABI, deployer);
    });

    describe('Basic', () => {
      it("Should be set with correct initial vaule", async () => {
        expect(await priceOracle.owner()).equal(deployer.address);

        expect(await vault.owner()).equal(deployer.address);
        expect(await vault.admin()).equal(common.admin);
        expect(await vault.strategy()).equal(strategy.address);
        expect(await vault.priceOracle()).equal(priceOracle.address);
        expect(await vault.USDT()).equal(network_.Swap.USDT);

        expect(await strategy.owner()).equal(deployer.address);
        expect(await strategy.treasuryWallet()).equal(common.treasury);
        expect(await strategy.admin()).equal(common.admin);
        expect(await strategy.vault()).equal(vault.address);
        expect(await strategy.priceOracle()).equal(priceOracle.address);
        expect(await strategy.router()).equal(network_.Swap.router);
        expect(await strategy.SWAP_BASE_TOKEN()).equal(network_.Swap.SWAP_BASE_TOKEN);
        expect(await strategy.USDT()).equal(network_.Swap.USDT);
        expect(await strategy.tokens(0)).equal(network_.Swap.WCNDL);
        expect(await strategy.pid(network_.Swap.WCNDL)).equal(0);
        const WCNDLVaultAddr = await strategy.WCNDLVault();

        const WCNDLVault = new ethers.Contract(WCNDLVaultAddr, l2VaultArtifact.abi, a1);
        expect(await WCNDLVault.name()).equal('BNI L2 WCNDL');
        expect(await WCNDLVault.symbol()).equal('bniL2WCNDL');
        expect(await WCNDLVault.aToken()).equal(network_.Aave3.aPolWCNDL);
        expect(await WCNDLVault.admin()).equal(common.admin);
        expect(await WCNDLVault.treasuryWallet()).equal(common.treasury);
        expect(await WCNDLVault.yieldFee()).equal(2000);
      });

      it("Should be set by only owner", async () => {
        await expectRevert(priceOracle.setAssetSources([a2.address],[a1.address]), "Ownable: caller is not the owner");

        await expectRevert(vault.setAdmin(a2.address), "Ownable: caller is not the owner");
        await expectRevert(vault.deposit(a1.address, [a2.address], [getUsdtAmount('100')]), "Only owner or admin");
        await expectRevert(vault.withdrawPerc(a1.address, parseEther('0.1')), "Only owner or admin");
        await expectRevert(vault.rebalance(0, parseEther('0.1'), a2.address), "Only owner or admin");
        await expectRevert(vault.emergencyWithdraw(), "Only owner or admin");
        await expectRevert(vault.reinvest([a2.address], [10000]), "Only owner or admin");

        await expectRevert(strategy.addToken(a1.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.removeToken(1), "Ownable: caller is not the owner");
        await expectRevert(strategy.setTreasuryWallet(a2.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.setAdmin(a2.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.setVault(a2.address), "Ownable: caller is not the owner");

        const WCNDLVault = new ethers.Contract(await strategy.WCNDLVault(), l2VaultArtifact.abi, a1);

        await expectRevert(WCNDLVault.setAdmin(a2.address), "Ownable: caller is not the owner");
        await WCNDLVault.connect(deployer).setAdmin(a2.address);
        expect(await WCNDLVault.admin()).equal(a2.address);
        await WCNDLVault.connect(deployer).setAdmin(admin.address);

        await expectRevert(WCNDLVault.setTreasuryWallet(a2.address), "Ownable: caller is not the owner");
        await WCNDLVault.connect(deployer).setTreasuryWallet(a2.address);
        expect(await WCNDLVault.treasuryWallet()).equal(a2.address);
        await WCNDLVault.connect(deployer).setTreasuryWallet(common.treasury);

        await expectRevert(WCNDLVault.setFee(1000), "Ownable: caller is not the owner");
        await WCNDLVault.connect(deployer).setFee(1000);
        expect(await WCNDLVault.yieldFee()).equal(1000);

        await expectRevert(WCNDLVault.yield(), "Only owner or admin");
        await WCNDLVault.connect(admin).yield();

        await expectRevert(WCNDLVault.emergencyWithdraw(), "Only owner or admin");
        await WCNDLVault.connect(admin).emergencyWithdraw();
        await expectRevert(WCNDLVault.connect(deployer).emergencyWithdraw(), "Pausable: paused");

        await expectRevert(WCNDLVault.reinvest(), "Only owner or admin");
        await WCNDLVault.connect(admin).reinvest();
        await expectRevert(WCNDLVault.connect(deployer).reinvest(), "Pausable: not paused");
      });

      it("Should be returned with correct default vaule", async () => {
        expect(await vault.getAPR()).gt(0);
        expect(await vault.getAllPoolInUSD()).equal(0);

        var ret = await vault.getEachPoolInUSD();
        chainIDs = ret[0];
        tokens = ret[1];
        pools = ret[2];
        expect(chainIDs.length).equal(1);
        // expect(chainIDs[0]).equal(137);
        expect(tokens[0]).equal('0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270');
        expect(pools[0]).equal(0);
      });
    });

    describe('Basic function', () => {
      it("Basic Deposit/withdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        const WCNDLVault = new ethers.Contract(await strategy.WCNDLVault(), l2VaultArtifact.abi, a1);
        expect(await WCNDLVault.getAPR()).gt(0);

        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await vault.connect(admin).deposit(a1.address, tokens, [getUsdtAmount('50000')]);
        expect(await usdt.balanceOf(a1.address)).equal(0);
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(10));

        await increaseTime(DAY);
        expect(await WCNDLVault.getPendingRewards()).equal(0);
        await WCNDLVault.connect(admin).yield();

        await vault.connect(admin).withdrawPerc(a1.address, parseEther('1'));
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(10));
        expect(await vault.getAllPoolInUSD()).equal(0);
      });

      it("emergencyWithdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await vault.connect(admin).deposit(a1.address, tokens, [getUsdtAmount('50000')]);

        await vault.connect(admin).emergencyWithdraw();
        expect(await usdt.balanceOf(vault.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(20));

        ret = await vault.getCurrentCompositionPerc();
        await vault.connect(admin).reinvest(ret[0], ret[1]);
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(10));

        await vault.connect(admin).emergencyWithdraw();

        await vault.connect(admin).withdrawPerc(a1.address, parseEther('1'));
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(10));
        expect(await vault.getAllPoolInUSD()).equal(0);
      });

      it("Rebalance", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('10000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('10000'));

        await strategy.connect(deployer).addToken(network_.Swap.USDT);
        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await vault.connect(admin).deposit(a1.address, tokens, [getUsdtAmount('6000'),getUsdtAmount('4000')]);
        expect(await usdt.balanceOf(a1.address)).equal(0);
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('10000'), parseEther('10000').div(50));

        var tokenPerc = await vault.getCurrentCompositionPerc();
        expect(tokenPerc[0][0]).equal(network_.Swap.WCNDL);
        expect(tokenPerc[0][1]).equal(network_.Swap.USDT);
        expect(tokenPerc[1][0].toNumber()).closeTo(6000, 6000/50);
        expect(tokenPerc[1][1].toNumber()).closeTo(4000, 4000/50);

        await expectRevert(strategy.connect(deployer).removeToken(2), "Invalid pid")
        await expectRevert(strategy.connect(deployer).removeToken(1), "Pool is not empty")

        await vault.connect(admin).rebalance(1, parseEther('1'), network_.Swap.WCNDL);
        tokenPerc = await vault.getCurrentCompositionPerc();
        expect(tokenPerc[0][0]).equal(network_.Swap.WMATIC);
        expect(tokenPerc[0][1]).equal(network_.Swap.USDT);
        expect(tokenPerc[1][0].toNumber()).equal(10000);
        expect(tokenPerc[1][1].toNumber()).equal(0);

        await strategy.connect(deployer).removeToken(1);
        await vault.connect(admin).withdrawPerc(a1.address, parseEther('1'));
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('10000'), getUsdtAmount('10000').div(10));
        expect(await vault.getAllPoolInUSD()).equal(0);
      });
    });
});
