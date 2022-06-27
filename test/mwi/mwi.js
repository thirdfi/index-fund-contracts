const { expect } = require("chai");
const { assert, ethers, deployments } = require("hardhat");
const { expectRevert } = require('@openzeppelin/test-helpers');
const { BigNumber } = ethers;
const parseEther = ethers.utils.parseEther;
const { increaseTime } = require("../../scripts/utils/ethereum");

const ERC20_ABI = require("../../node_modules/@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable.json").abi;

const { common, avaxMainnet: network_ } = require("../../parameters");

const DAY = 24 * 3600;

function getUsdtAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}

describe("MWI", async () => {

    let vault, strategy, usdt;
    let vaultArtifact, strategyArtifact;
    let admin;

    before(async () => {
      [deployer, a1, a2, ...accounts] = await ethers.getSigners();
  
      vaultArtifact = await deployments.getArtifact("MWIVault");
      strategyArtifact = await deployments.getArtifact("MWIStrategy");
      l2VaultArtifact = await deployments.getArtifact("Aave3Vault");
    });
  
    beforeEach(async () => {
      await deployments.fixture(["hardhat_avax_mwi"])
  
      const vaultProxy = await ethers.getContract("MWIVault_Proxy");
      vault = new ethers.Contract(vaultProxy.address, vaultArtifact.abi, a1);
      const strategyProxy = await ethers.getContract("MWIStrategy_Proxy");
      strategy = new ethers.Contract(strategyProxy.address, strategyArtifact.abi, a1);

      admin = await ethers.getSigner(common.admin);

      usdt = new ethers.Contract('0xc7198437980c041c805A1EDcbA50c1Ce5db95118', ERC20_ABI, deployer);
    });

    describe('Basic', () => {
      it("Should be set with correct initial vaule", async () => {
        expect(await vault.owner()).equal(deployer.address);
        expect(await vault.admin()).equal(common.admin);
        expect(await vault.treasuryWallet()).equal(common.treasury);
        expect(await vault.trustedForwarder()).equal(network_.biconomy);
        expect(await vault.strategy()).equal(strategy.address);
        expect(await vault.name()).equal('Market Weighted Index');
        expect(await vault.symbol()).equal('MWI');
        expect(await vault.versionRecipient()).equal('1');
        expect(await vault.profitFeePerc()).equal(2000);

        expect(await strategy.vault()).equal(vault.address);
        expect(await strategy.targetPercentages(0)).equal(4500);
        expect(await strategy.targetPercentages(1)).equal(3500);
        expect(await strategy.targetPercentages(2)).equal(1500);
        expect(await strategy.targetPercentages(3)).equal(500);
        const WBTCVaultAddr = await strategy.WBTCVault();
        const WETHVaultAddr = await strategy.WETHVault();
        const WAVAXVaultAddr = await strategy.WAVAXVault();
        const USDTVaultAddr = await strategy.USDTVault();

        const WBTCVault = new ethers.Contract(WBTCVaultAddr, l2VaultArtifact.abi, a1);
        expect(await WBTCVault.name()).equal('MWI L2 WBTC');
        expect(await WBTCVault.symbol()).equal('mwiL2WBTC');
        expect(await WBTCVault.aToken()).equal(network_.Aave3.aAvaWBTC);
        expect(await WBTCVault.admin()).equal(common.admin);
        expect(await WBTCVault.treasuryWallet()).equal(common.treasury);
        expect(await WBTCVault.yieldFee()).equal(2000);

        const WETHVault = new ethers.Contract(WETHVaultAddr, l2VaultArtifact.abi, a1);
        expect(await WETHVault.name()).equal('MWI L2 WETH');
        expect(await WETHVault.symbol()).equal('mwiL2WETH');
        expect(await WETHVault.aToken()).equal(network_.Aave3.aAvaWETH);
        expect(await WETHVault.admin()).equal(common.admin);
        expect(await WETHVault.treasuryWallet()).equal(common.treasury);
        expect(await WETHVault.yieldFee()).equal(2000);

        const WAVAXVault = new ethers.Contract(WAVAXVaultAddr, l2VaultArtifact.abi, a1);
        expect(await WAVAXVault.name()).equal('MWI L2 WAVAX');
        expect(await WAVAXVault.symbol()).equal('mwiL2WAVAX');
        expect(await WAVAXVault.aToken()).equal(network_.Aave3.aAvaWAVAX);
        expect(await WAVAXVault.admin()).equal(common.admin);
        expect(await WAVAXVault.treasuryWallet()).equal(common.treasury);
        expect(await WAVAXVault.yieldFee()).equal(2000);

        const USDTVault = new ethers.Contract(USDTVaultAddr, l2VaultArtifact.abi, a1);
        expect(await USDTVault.name()).equal('MWI L2 USDT');
        expect(await USDTVault.symbol()).equal('mwiL2USDT');
        expect(await USDTVault.aToken()).equal(network_.Aave3.aAvaUSDT);
        expect(await USDTVault.admin()).equal(common.admin);
        expect(await USDTVault.treasuryWallet()).equal(common.treasury);
        expect(await USDTVault.yieldFee()).equal(2000);
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

        await expectRevert(vault.setProfitFeePerc(1000), "Ownable: caller is not the owner");
        await expectRevert(vault.collectProfitAndUpdateWatermark(), "Only owner or admin");
        await expectRevert(vault.withdrawFees(), "Only owner or admin");

        await expectRevert(vault.setBiconomy(a2.address), "Ownable: caller is not the owner");
        await vault.connect(deployer).setBiconomy(a2.address);
        expect(await vault.trustedForwarder()).equal(a2.address);
        await vault.connect(deployer).setBiconomy(network_.biconomy);

        await expectRevert(vault.emergencyWithdraw(), "Only owner or admin");
        await vault.connect(admin).emergencyWithdraw();
        await expectRevert(vault.connect(deployer).emergencyWithdraw(), "Pausable: paused");

        await expectRevert(vault.reinvest(), "Only owner or admin");
        await vault.connect(admin).reinvest();
        await expectRevert(vault.connect(deployer).reinvest(), "Pausable: not paused");

        await expectRevert(vault.rebalance(0, 1000), "Only owner or admin");
        await vault.connect(admin).rebalance(0, 1000);

        await expectRevert(vault.depositByAdmin(a1.address, 0), "Only owner or admin");
        await expectRevert(vault.withdrawByAdmin(a1.address, 0), "Only owner or admin");

        await expectRevert(strategy.setTokenCompositionTargetPerc([4000,3000,2000,1000]), "Ownable: caller is not the owner");
        await expectRevert(strategy.connect(deployer).setTokenCompositionTargetPerc([4000,3000,2000]), "Invalid count");
        await expectRevert(strategy.connect(deployer).setTokenCompositionTargetPerc([4000,3000,2000,500]), "Invalid parameter");
        await strategy.connect(deployer).setTokenCompositionTargetPerc([4000,3000,2000,1000]);
        expect(await strategy.targetPercentages(0)).equal(4000);
        expect(await strategy.targetPercentages(1)).equal(3000);
        expect(await strategy.targetPercentages(2)).equal(2000);
        expect(await strategy.targetPercentages(3)).equal(1000);

        const WBTCVault = new ethers.Contract(await strategy.WBTCVault(), l2VaultArtifact.abi, a1);

        await expectRevert(WBTCVault.setAdmin(a2.address), "Ownable: caller is not the owner");
        await WBTCVault.connect(deployer).setAdmin(a2.address);
        expect(await WBTCVault.admin()).equal(a2.address);
        await WBTCVault.connect(deployer).setAdmin(admin.address);

        await expectRevert(WBTCVault.setTreasuryWallet(a2.address), "Ownable: caller is not the owner");
        await WBTCVault.connect(deployer).setTreasuryWallet(a2.address);
        expect(await WBTCVault.treasuryWallet()).equal(a2.address);
        await WBTCVault.connect(deployer).setTreasuryWallet(common.treasury);

        await expectRevert(WBTCVault.setFee(1000), "Ownable: caller is not the owner");
        await WBTCVault.connect(deployer).setFee(1000);
        expect(await WBTCVault.yieldFee()).equal(1000);

        await expectRevert(WBTCVault.yield(), "Only owner or admin");
        await WBTCVault.connect(admin).yield();

        await expectRevert(WBTCVault.emergencyWithdraw(), "Only owner or admin");
        await WBTCVault.connect(admin).emergencyWithdraw();
        await expectRevert(WBTCVault.connect(deployer).emergencyWithdraw(), "Pausable: paused");

        await expectRevert(WBTCVault.reinvest(), "Only owner or admin");
        await WBTCVault.connect(admin).reinvest();
        await expectRevert(WBTCVault.connect(deployer).reinvest(), "Pausable: not paused");
      });
    });

    describe('Basic function', () => {
      it("Basic Deposit/withdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        const WBTCVault = new ethers.Contract(await strategy.WBTCVault(), l2VaultArtifact.abi, a1);
        const WETHVault = new ethers.Contract(await strategy.WETHVault(), l2VaultArtifact.abi, a1);
        const WAVAXVault = new ethers.Contract(await strategy.WAVAXVault(), l2VaultArtifact.abi, a1);
        const USDTVault = new ethers.Contract(await strategy.USDTVault(), l2VaultArtifact.abi, a1);
        expect(await WBTCVault.getAPR()).gt(0);
        expect(await WETHVault.getAPR()).gt(0);
        expect(await WAVAXVault.getAPR()).gt(0);
        expect(await USDTVault.getAPR()).gt(0);
        expect(await vault.getAPR()).gt(0);

        expect(await vault.getAllPoolInUSD()).equal(0);
        expect(await vault.getPricePerFullShare()).equal(parseEther('1'));

        await vault.deposit(getUsdtAmount('50000'));
        expect(await vault.balanceOf(a1.address)).closeTo(parseEther('50000'), parseEther('50000').div(100));
        expect(await vault.totalSupply()).closeTo(parseEther('50000'), parseEther('50000').div(100));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(50));

        await increaseTime(DAY);
        expect(await WBTCVault.getPendingRewards()).gt(0);
        expect(await WETHVault.getPendingRewards()).gt(0);
        expect(await WAVAXVault.getPendingRewards()).gt(0);
        expect(await USDTVault.getPendingRewards()).gt(0);

        await WBTCVault.connect(admin).yield();
        await WETHVault.connect(admin).yield();
        await WAVAXVault.connect(admin).yield();
        await USDTVault.connect(admin).yield();

        await vault.withdraw(await vault.balanceOf(a1.address));
        expect(await vault.totalSupply()).equal(0);
        expect(await vault.balanceOf(a1.address)).equal(0);
        expect(await vault.getAllPoolInUSD()).equal(0);
        expect(await vault.getPricePerFullShare()).equal(parseEther('1'));
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(50));
      });

      it("Deposit/withdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('30000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('30000'));
        await usdt.transfer(a2.address, getUsdtAmount('30000'));
        await usdt.connect(a2).approve(vault.address, getUsdtAmount('30000'));

        await vault.deposit(getUsdtAmount('30000'));
        await vault.connect(a2).deposit(getUsdtAmount('30000'));
        expect(await vault.balanceOf(a2.address)).closeTo(parseEther('30000'), parseEther('30000').div(100));
        expect(await vault.totalSupply()).closeTo(parseEther('60000'), parseEther('60000').div(100));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('60000'), parseEther('60000').div(20));

        await increaseTime(DAY);

        await vault.withdraw(await vault.balanceOf(a1.address));
        expect(await vault.totalSupply()).closeTo(parseEther('30000'), parseEther('30000').div(100));

        await vault.connect(a2).withdraw(await vault.balanceOf(a2.address));
        expect(await vault.totalSupply()).equal(0);
        expect(await vault.balanceOf(a2.address)).equal(0);
        expect(await vault.getAllPoolInUSD()).equal(0);
        expect(await vault.getPricePerFullShare()).equal(parseEther('1'));
        expect(await usdt.balanceOf(a2.address)).closeTo(getUsdtAmount('30000'), getUsdtAmount('30000').div(20));
      });

      it("emergencyWithdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        await vault.deposit(getUsdtAmount('50000'));

        await vault.connect(admin).emergencyWithdraw();
        expect(await usdt.balanceOf(vault.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(20));
        await vault.connect(admin).reinvest();

        await vault.withdraw(await vault.balanceOf(a1.address));
        expect(await vault.totalSupply()).equal(0);
        expect(await vault.balanceOf(a1.address)).equal(0);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(20));
      });

      it("Rebalance", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        await vault.deposit(getUsdtAmount('50000'));

        var tokenPerc = await vault.getCurrentCompositionPerc();
        expect(tokenPerc[0][0]).equal('0x50b7545627a5162F82A992c33b87aDc75187B218');
        expect(tokenPerc[0][1]).equal('0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB');
        expect(tokenPerc[0][2]).equal('0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7');
        expect(tokenPerc[0][3]).equal('0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7');
        expect(tokenPerc[1][0].toNumber()).closeTo(4500, 4500/100);
        expect(tokenPerc[1][1].toNumber()).closeTo(3500, 3500/100);
        expect(tokenPerc[1][2].toNumber()).closeTo(1500, 1500/100);
        expect(tokenPerc[1][3].toNumber()).closeTo(500, 500/50);

        await vault.connect(admin).rebalance(0, 1000);

        tokenPerc = await vault.getCurrentCompositionPerc();
        expect(tokenPerc[1][0].toNumber()).closeTo(4500, 4500/100);
        expect(tokenPerc[1][1].toNumber()).closeTo(3500, 3500/100);
        expect(tokenPerc[1][2].toNumber()).closeTo(1500, 1500/100);
        expect(tokenPerc[1][3].toNumber()).closeTo(500, 500/50);
      });
    });

});