const { expect } = require("chai");
const { assert, ethers, deployments } = require("hardhat");
const { expectRevert } = require('@openzeppelin/test-helpers');
const { BigNumber } = ethers;
const parseEther = ethers.utils.parseEther;
const { increaseTime } = require("../../scripts/utils/ethereum");

const ERC20_ABI = require("../../node_modules/@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable.json").abi;

const { common, bscMainnet: network_ } = require("../../parameters");

const DAY = 24 * 3600;

function getUsdtAmount(amount) {
  return parseEther(amount);
}

describe("LCI", async () => {

    let vault, strategy, usdt;
    let vaultArtifact, strategyArtifact;
    let admin;

    before(async () => {
      [deployer, a1, a2, ...accounts] = await ethers.getSigners();
  
      vaultArtifact = await deployments.getArtifact("LCIVault");
      strategyArtifact = await deployments.getArtifact("LCIStrategy");
      l2VaultArtifact = await deployments.getArtifact("BscVault");
    });
  
    beforeEach(async () => {
      await deployments.fixture(["hardhat_bsc_lci"])
  
      const vaultProxy = await ethers.getContract("LCIVault_Proxy");
      vault = new ethers.Contract(vaultProxy.address, vaultArtifact.abi, a1);
      const strategyProxy = await ethers.getContract("LCIStrategy_Proxy");
      strategy = new ethers.Contract(strategyProxy.address, strategyArtifact.abi, a1);

      admin = await ethers.getSigner(common.admin);

      usdt = new ethers.Contract('0x55d398326f99059fF775485246999027B3197955', ERC20_ABI, deployer);
    });

    describe('Basic', () => {
      it("Should be set with correct initial vaule", async () => {
        expect(await vault.owner()).equal(deployer.address);
        expect(await vault.admin()).equal(common.admin);
        expect(await vault.treasuryWallet()).equal(common.treasury);
        expect(await vault.trustedForwarder()).equal(network_.biconomy);
        expect(await vault.strategy()).equal(strategy.address);
        expect(await vault.name()).equal('Low-risk Crypto Index');
        expect(await vault.symbol()).equal('LCI');
        expect(await vault.versionRecipient()).equal('1');
        expect(await vault.profitFeePerc()).equal(2000);

        expect(await strategy.vault()).equal(vault.address);
        expect(await strategy.USDTUSDCTargetPerc()).equal(6000);
        expect(await strategy.USDTBUSDTargetPerc()).equal(2000);
        expect(await strategy.USDCBUSDTargetPerc()).equal(2000);
        const USDTUSDCVaultAddr = await strategy.USDTUSDCVault();
        const USDTBUSDVaultAddr = await strategy.USDTBUSDVault();
        const USDCBUSDVaultAddr = await strategy.USDCBUSDVault();

        const USDTUSDCVault = new ethers.Contract(USDTUSDCVaultAddr, l2VaultArtifact.abi, a1);
        expect(await USDTUSDCVault.name()).equal('LCI L2 USDT-USDC');
        expect(await USDTUSDCVault.symbol()).equal('lciL2USDTC');
        expect(await USDTUSDCVault.pid()).equal(network_.PancakeSwap.Farm_USDT_USDC_pid);
        expect(await USDTUSDCVault.lpToken()).equal('0xEc6557348085Aa57C72514D67070dC863C0a5A8c');
        expect(await USDTUSDCVault.admin()).equal(common.admin);
        expect(await USDTUSDCVault.treasuryWallet()).equal(common.treasury);
        expect(await USDTUSDCVault.yieldFee()).equal(2000);
        expect(await USDTUSDCVault.lpRewardApr()).equal(0);
        expect(await USDTUSDCVault.lpReservePerShare()).gt(0);
        expect(await USDTUSDCVault.lpDataLastUpdate()).gt(0);

        const USDTBUSDVault = new ethers.Contract(USDTBUSDVaultAddr, l2VaultArtifact.abi, a1);
        expect(await USDTBUSDVault.name()).equal('LCI L2 USDT-BUSD');
        expect(await USDTBUSDVault.symbol()).equal('lciL2USDTB');
        expect(await USDTBUSDVault.pid()).equal(network_.PancakeSwap.Farm_USDT_BUSD_pid);
        expect(await USDTBUSDVault.lpToken()).equal('0x7EFaEf62fDdCCa950418312c6C91Aef321375A00');
        expect(await USDTBUSDVault.admin()).equal(common.admin);
        expect(await USDTBUSDVault.treasuryWallet()).equal(common.treasury);
        expect(await USDTBUSDVault.yieldFee()).equal(2000);
        expect(await USDTBUSDVault.lpRewardApr()).equal(0);
        expect(await USDTBUSDVault.lpReservePerShare()).gt(0);
        expect(await USDTBUSDVault.lpDataLastUpdate()).gt(0);

        const USDCBUSDVault = new ethers.Contract(USDCBUSDVaultAddr, l2VaultArtifact.abi, a1);
        expect(await USDCBUSDVault.name()).equal('LCI L2 USDC-BUSD');
        expect(await USDCBUSDVault.symbol()).equal('lciL2USDCB');
        expect(await USDCBUSDVault.pid()).equal(network_.PancakeSwap.Farm_USDC_BUSD_pid);
        expect(await USDCBUSDVault.lpToken()).equal('0x2354ef4DF11afacb85a5C7f98B624072ECcddbB1');
        expect(await USDCBUSDVault.admin()).equal(common.admin);
        expect(await USDCBUSDVault.treasuryWallet()).equal(common.treasury);
        expect(await USDCBUSDVault.yieldFee()).equal(2000);
        expect(await USDCBUSDVault.lpRewardApr()).equal(0);
        expect(await USDCBUSDVault.lpReservePerShare()).gt(0);
        expect(await USDCBUSDVault.lpDataLastUpdate()).gt(0);
      });

      it("Should be set by only owner", async () => {
        await expectRevert(vault.setAdmin(a2.address), "Ownable: caller is not the owner");
        await vault.connect(deployer).setAdmin(a2.address);
        expect(await vault.admin()).equal(a2.address);
        await vault.connect(deployer).setAdmin(admin.address);

        await expectRevert(vault.setTreasuryWallet(a2.address), "Ownable: caller is not the owner");
        await vault.connect(deployer).setTreasuryWallet(a2.address);
        expect(await vault.treasuryWallet()).equal(a2.address);
        await vault.connect(deployer).setTreasuryWallet(common.treasury);

        await expectRevert(vault.setBiconomy(a2.address), "Ownable: caller is not the owner");
        await vault.connect(deployer).setBiconomy(a2.address);
        expect(await vault.trustedForwarder()).equal(a2.address);
        await vault.connect(deployer).setBiconomy(network_.biconomy);

        await expectRevert(vault.setProfitFeePerc(1000), "Ownable: caller is not the owner");
        await expectRevert(vault.collectProfitAndUpdateWatermark(), "Only owner or admin");
        await expectRevert(vault.withdrawFees(), "Only owner or admin");

        await expectRevert(vault.emergencyWithdraw(), "Only owner or admin");
        await vault.connect(admin).emergencyWithdraw();
        await expectRevert(vault.connect(deployer).emergencyWithdraw(), "Pausable: paused");

        await expectRevert(vault.reinvest(), "Only owner or admin");
        await vault.connect(admin).reinvest();
        await expectRevert(vault.connect(deployer).reinvest(), "Pausable: not paused");

        await expectRevert(vault.rebalance(0, 1000), "Only owner or admin");
        await vault.connect(admin).rebalance(0, 1000);

        await expectRevert(strategy.setLPCompositionTargetPerc([4000,3000,3000]), "Ownable: caller is not the owner");
        await expectRevert(strategy.connect(deployer).setLPCompositionTargetPerc([4000,3000]), "Invalid count");
        await expectRevert(strategy.connect(deployer).setLPCompositionTargetPerc([4000,3000,2000]), "Invalid parameter");
        await strategy.connect(deployer).setLPCompositionTargetPerc([4000,3000,3000]);
        expect(await strategy.USDTUSDCTargetPerc()).equal(4000);
        expect(await strategy.USDTBUSDTargetPerc()).equal(3000);
        expect(await strategy.USDCBUSDTargetPerc()).equal(3000);

        const USDTUSDCVault = new ethers.Contract(await strategy.USDTUSDCVault(), l2VaultArtifact.abi, a1);

        await expectRevert(USDTUSDCVault.setAdmin(a2.address), "Ownable: caller is not the owner");
        await USDTUSDCVault.connect(deployer).setAdmin(a2.address);
        expect(await USDTUSDCVault.admin()).equal(a2.address);
        await USDTUSDCVault.connect(deployer).setAdmin(admin.address);

        await expectRevert(USDTUSDCVault.setTreasuryWallet(a2.address), "Ownable: caller is not the owner");
        await USDTUSDCVault.connect(deployer).setTreasuryWallet(a2.address);
        expect(await USDTUSDCVault.treasuryWallet()).equal(a2.address);
        await USDTUSDCVault.connect(deployer).setTreasuryWallet(common.treasury);

        await expectRevert(USDTUSDCVault.setFee(1000), "Ownable: caller is not the owner");
        await USDTUSDCVault.connect(deployer).setFee(1000);
        expect(await USDTUSDCVault.yieldFee()).equal(1000);

        await expectRevert(USDTUSDCVault.yield(), "Only owner or admin");
        await USDTUSDCVault.connect(admin).yield();

        await expectRevert(USDTUSDCVault.emergencyWithdraw(), "Only owner or admin");
        await USDTUSDCVault.connect(admin).emergencyWithdraw();
        await expectRevert(USDTUSDCVault.connect(deployer).emergencyWithdraw(), "Pausable: paused");

        await expectRevert(USDTUSDCVault.reinvest(), "Only owner or admin");
        await USDTUSDCVault.connect(admin).reinvest();
        await expectRevert(USDTUSDCVault.connect(deployer).reinvest(), "Pausable: not paused");
      });
    });

    describe('Basic function', () => {
      it("Basic Deposit/withdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        const USDTUSDCVault = new ethers.Contract(await strategy.USDTUSDCVault(), l2VaultArtifact.abi, a1);
        const USDTBUSDVault = new ethers.Contract(await strategy.USDTBUSDVault(), l2VaultArtifact.abi, a1);
        const USDCBUSDVault = new ethers.Contract(await strategy.USDCBUSDVault(), l2VaultArtifact.abi, a1);
        expect(await USDTUSDCVault.getAPR()).gt(0);
        expect(await USDTBUSDVault.getAPR()).gt(0);
        expect(await USDCBUSDVault.getAPR()).gt(0);
        expect(await vault.getAPR()).gt(0);

        expect(await vault.getAllPoolInUSD()).equal(0);
        expect(await vault.getPricePerFullShare()).equal(parseEther('1'));

        await vault.deposit(getUsdtAmount('50000'));
        expect(await vault.balanceOf(a1.address)).closeTo(parseEther('50000'), parseEther('50000').div(100));
        expect(await vault.totalSupply()).closeTo(parseEther('50000'), parseEther('50000').div(100));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(100));

        await increaseTime(DAY);
        expect(await USDTUSDCVault.getPendingRewards()).gt(0);
        expect(await USDTBUSDVault.getPendingRewards()).gt(0);
        expect(await USDCBUSDVault.getPendingRewards()).gt(0);

        await USDTUSDCVault.connect(admin).yield();
        await USDTBUSDVault.connect(admin).yield();
        await USDCBUSDVault.connect(admin).yield();

        await vault.withdraw(await vault.balanceOf(a1.address));
        expect(await vault.totalSupply()).equal(0);
        expect(await vault.balanceOf(a1.address)).equal(0);
        expect(await vault.getAllPoolInUSD()).equal(0);
        expect(await vault.getPricePerFullShare()).equal(parseEther('1'));
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(100));
      });

      it("Deposit/withdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));
        await usdt.transfer(a2.address, getUsdtAmount('50000'));
        await usdt.connect(a2).approve(vault.address, getUsdtAmount('50000'));

        await vault.deposit(getUsdtAmount('50000'));
        await vault.connect(a2).deposit(getUsdtAmount('50000'));
        expect(await vault.balanceOf(a2.address)).closeTo(parseEther('50000'), parseEther('50000').div(100));
        expect(await vault.totalSupply()).closeTo(parseEther('100000'), parseEther('100000').div(100));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('100000'), parseEther('100000').div(100));

        await increaseTime(DAY);

        await vault.withdraw(await vault.balanceOf(a1.address));
        expect(await vault.totalSupply()).closeTo(parseEther('50000'), parseEther('50000').div(100));

        await vault.connect(a2).withdraw(await vault.balanceOf(a2.address));
        expect(await vault.totalSupply()).equal(0);
        expect(await vault.balanceOf(a2.address)).equal(0);
        expect(await vault.getAllPoolInUSD()).equal(0);
        expect(await vault.getPricePerFullShare()).equal(parseEther('1'));
        expect(await usdt.balanceOf(a2.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(100));
      });

      it("emergencyWithdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        await vault.deposit(getUsdtAmount('50000'));

        await vault.connect(admin).emergencyWithdraw();
        expect(await usdt.balanceOf(vault.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(100));
        await vault.connect(admin).reinvest();

        await vault.withdraw(await vault.balanceOf(a1.address));
        expect(await vault.totalSupply()).equal(0);
        expect(await vault.balanceOf(a1.address)).equal(0);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(100));
      });

      it("Rebalance", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        var lpPerc = await strategy.getCurrentLPCompositionPerc();
        expect(lpPerc[0]).equal(6000);
        expect(lpPerc[1]).equal(2000);
        expect(lpPerc[2]).equal(2000);

        await vault.deposit(getUsdtAmount('50000'));

        lpPerc = await strategy.getCurrentLPCompositionPerc();
        expect(lpPerc[0].toNumber()).closeTo(6000, 6000/100);
        expect(lpPerc[1].toNumber()).closeTo(2000, 2000/100);
        expect(lpPerc[2].toNumber()).closeTo(2000, 2000/100);

        var tokenPerc = await vault.getCurrentCompositionPerc();
        expect(tokenPerc[0][0]).equal('0x55d398326f99059fF775485246999027B3197955');
        expect(tokenPerc[0][1]).equal('0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d');
        expect(tokenPerc[0][2]).equal('0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56');
        expect(tokenPerc[1][0].toNumber()).closeTo(4000, 4000/100);
        expect(tokenPerc[1][1].toNumber()).closeTo(4000, 4000/100);
        expect(tokenPerc[1][2].toNumber()).closeTo(2000, 2000/100);

        await vault.connect(admin).rebalance(0, 1000);

        tokenPerc = await vault.getCurrentCompositionPerc();
        expect(tokenPerc[1][0].toNumber()).closeTo(4000, 4000/100);
        expect(tokenPerc[1][1].toNumber()).closeTo(4000, 4000/100);
        expect(tokenPerc[1][2].toNumber()).closeTo(2000, 2000/100);
      });
    });

});