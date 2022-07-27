const { expect } = require("chai");
const { assert, ethers, deployments } = require("hardhat");
const { expectRevert } = require('@openzeppelin/test-helpers');
const { BigNumber } = ethers;
const parseEther = ethers.utils.parseEther;
const { increaseTime } = require("../../scripts/utils/ethereum");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable.json").abi;

const { common, auroraMainnet: network_ } = require("../../parameters");

const DAY = 24 * 3600;

function getUsdtAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}
function getWNearAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(24))
}
function e(decimals) {
  return BigNumber.from(10).pow(decimals)
}

describe("STI on Aurora", async () => {

    let vault, strategy, stVault, priceOracle, usdt, nft;
    let vaultArtifact, strategyArtifact, stVaultArtifact, l2VaultArtifact, priceOracleArtifact, nftArtifact;
    let admin;

    before(async () => {
      [deployer, a1, a2, ...accounts] = await ethers.getSigners();
  
      vaultArtifact = await deployments.getArtifact("STIVault");
      strategyArtifact = await deployments.getArtifact("AuroraSTIStrategy");
      stVaultArtifact = await deployments.getArtifact("AuroraStNEARVault");
      nftArtifact = await deployments.getArtifact("StVaultNFT");
      l2VaultArtifact = await deployments.getArtifact("AuroraBastionVault");
      priceOracleArtifact = await deployments.getArtifact("AuroraPriceOracle");
    });

    beforeEach(async () => {
      await deployments.fixture(["hardhat_aurora_sti"])

      const vaultProxy = await ethers.getContract("STIVault_Proxy");
      vault = new ethers.Contract(vaultProxy.address, vaultArtifact.abi, a1);
      const strategyProxy = await ethers.getContract("AuroraSTIStrategy_Proxy");
      strategy = new ethers.Contract(strategyProxy.address, strategyArtifact.abi, a1);
      stVault = new ethers.Contract(await strategy.WNEARVault(), stVaultArtifact.abi, a1);
      nft = new ethers.Contract(await stVault.nft(), nftArtifact.abi, a1);
      const priceOracleProxy = await ethers.getContract("AuroraPriceOracle_Proxy");
      priceOracle = new ethers.Contract(priceOracleProxy.address, priceOracleArtifact.abi, a1);

      admin = await ethers.getSigner(common.admin);

      usdt = new ethers.Contract(network_.Swap.USDT, ERC20_ABI, deployer);
    });

    describe('Basic', () => {
      let nftFactory;

      beforeEach(async () => {
        nftFactory = await ethers.getContract("StVaultNFTFactory");
      });
  
      it("Should be set with correct initial vaule", async () => {
        expect(await priceOracle.owner()).equal(deployer.address);

        expect(await vault.owner()).equal(deployer.address);
        expect(await vault.admin()).equal(common.admin);
        expect(await vault.strategy()).equal(strategy.address);
        expect(await vault.priceOracle()).equal(priceOracle.address);
        expect(await vault.USDT()).equal(network_.Swap.USDT);

        expect(await strategy.owner()).equal(deployer.address);
        expect(await strategy.admin()).equal(common.admin);
        expect(await strategy.vault()).equal(vault.address);
        expect(await strategy.priceOracle()).equal(priceOracle.address);
        expect(await strategy.router()).equal(network_.Swap.router);
        expect(await strategy.SWAP_BASE_TOKEN()).equal(network_.Swap.SWAP_BASE_TOKEN);
        expect(await strategy.USDT()).equal(network_.Swap.USDT);
        expect(await strategy.tokens(0)).equal(network_.Swap.WNEAR);
        expect(await strategy.pid(network_.Swap.WNEAR)).equal(0);

        expect(await stVault.name()).equal('STI Staking WNEAR');
        expect(await stVault.symbol()).equal('stiStNEAR');
        expect(await stVault.treasuryWallet()).equal(common.treasury);
        expect(await stVault.admin()).equal(common.admin);
        expect(await stVault.priceOracle()).equal(priceOracle.address);
        expect(await stVault.yieldFee()).equal(2000);
        expect(await stVault.nft()).equal(await nftFactory.getNFTByVault(stVault.address));
        expect(await stVault.token()).equal(network_.Swap.WNEAR);
        expect(await stVault.stToken()).equal(network_.Token.stNEAR);

        const l2stNEARVault = new ethers.Contract(await stVault.stNEARVault(), l2VaultArtifact.abi, a1);
        expect(await l2stNEARVault.name()).equal('STI L2 stNEAR');
        expect(await l2stNEARVault.symbol()).equal('stiL2stNEAR');
        expect(await l2stNEARVault.cToken()).equal(network_.Bastion.cstNEAR1);
        expect(await l2stNEARVault.admin()).equal(common.admin);
        expect(await l2stNEARVault.treasuryWallet()).equal(common.treasury);
        expect(await l2stNEARVault.yieldFee()).equal(2000);
      });

      it("Should be set by only owner", async () => {
        await expectRevert(priceOracle.setAssetSources([a2.address],[a1.address]), "Ownable: caller is not the owner");

        await expectRevert(vault.setAdmin(a2.address), "Ownable: caller is not the owner");
        await expectRevert(vault.depositByAdmin(a1.address, [a2.address], [getUsdtAmount('100')]), "Only owner or admin");
        await expectRevert(vault.withdrawPercByAdmin(a1.address, parseEther('0.1')), "Only owner or admin");
        await expectRevert(vault.emergencyWithdraw(), "Only owner or admin");
        await expectRevert(vault.claimEmergencyWithdrawal(), "Only owner or admin");
        await expectRevert(vault.reinvest([a2.address], [10000]), "Only owner or admin");
        await expectRevert(vault.setStrategy(a2.address), "Ownable: caller is not the owner");

        await expectRevert(strategy.addToken(a1.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.removeToken(1), "Ownable: caller is not the owner");
        await expectRevert(strategy.setAdmin(a2.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.setVault(a2.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.setStVault(a2.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.invest([a2.address], [getUsdtAmount('100')]), "Only vault");
        await expectRevert(strategy.withdrawPerc(a2.address, 1), "Only vault");
        await expectRevert(strategy.withdrawFromPool(a2.address, 1, 1), "Only vault");
        await expectRevert(strategy.emergencyWithdraw(), "Only vault");
        await expectRevert(strategy.claimEmergencyWithdrawal(), "Only vault");
        await expectRevert(strategy.claim(a2.address), "Only vault");

        await expectRevert(stVault.setAdmin(a2.address), "Ownable: caller is not the owner");
        await stVault.connect(deployer).setAdmin(a2.address);
        expect(await stVault.admin()).equal(a2.address);
        await stVault.connect(deployer).setAdmin(accounts[0].address);

        await expectRevert(stVault.setTreasuryWallet(a2.address), "Ownable: caller is not the owner");
        await stVault.connect(deployer).setTreasuryWallet(a2.address);
        expect(await stVault.treasuryWallet()).equal(a2.address);
        await stVault.connect(deployer).setTreasuryWallet(common.treasury);

        await expectRevert(stVault.setFee(1000), "Ownable: caller is not the owner");
        await stVault.connect(deployer).setFee(1000);
        expect(await stVault.yieldFee()).equal(1000);

        await expectRevert(stVault.setNFT(a2.address), "Ownable: caller is not the owner");
        await expectRevert(stVault.connect(deployer).setNFT(a2.address), "Already set");

        await expectRevert(stVault.setStakingPeriods(1,2,3,4), "Ownable: caller is not the owner");
        await stVault.connect(deployer).setStakingPeriods(1,2,3,4);
        expect(await stVault.unbondingPeriod()).equal(1);
        expect(await stVault.investInterval()).equal(2);
        expect(await stVault.redeemInterval()).equal(3);
        expect(await stVault.oneEpoch()).equal(4);

        await expectRevert(stVault.setStakingAmounts(5,6), "Ownable: caller is not the owner");
        await stVault.connect(deployer).setStakingAmounts(5,6);
        expect(await stVault.minInvestAmount()).equal(5);
        expect(await stVault.minRedeemAmount()).equal(6);
        await stVault.connect(deployer).setStakingAmounts(0,0);

        await expectRevert(stVault.resetApr(), "Ownable: caller is not the owner");
        await stVault.connect(deployer).resetApr();

        await expectRevert(stVault.invest(), "Only owner or admin");
        await stVault.connect(accounts[0]).invest();

        await expectRevert(stVault.redeem(), "Only owner or admin");
        await expectRevert(stVault.connect(accounts[0]).redeem(), "too small");

        await expectRevert(stVault.claimUnbonded(), "Only owner or admin");
        await stVault.connect(accounts[0]).claimUnbonded();

        await expectRevert(stVault.emergencyWithdraw(), "Only owner or admin");
        await stVault.connect(accounts[0]).emergencyWithdraw();
        await expectRevert(stVault.connect(deployer).emergencyWithdraw(), "Pausable: paused");

        await expectRevert(stVault.emergencyRedeem(), "Only owner or admin");
        await stVault.connect(accounts[0]).emergencyRedeem();

        await expectRevert(stVault.reinvest(), "Only owner or admin");
        await stVault.connect(accounts[0]).reinvest();
        await expectRevert(stVault.connect(deployer).reinvest(), "Pausable: not paused");

        await expectRevert(stVault.yield(), "Only owner or admin");
        await stVault.connect(accounts[0]).yield();

        await expectRevert(stVault.collectProfitAndUpdateWatermark(), "Only owner or admin");
        await stVault.connect(accounts[0]).collectProfitAndUpdateWatermark();

        await expectRevert(stVault.withdrawFees(), "Only owner or admin");
        await stVault.connect(accounts[0]).withdrawFees();
      });

      it("Should be returned with correct default vaule", async () => {
        expect(await vault.getAPR()).gt(0);
        expect(await vault.getAllPoolInUSD()).equal(0);

        var ret = await vault.getEachPoolInUSD();
        chainIDs = ret[0];
        tokens = ret[1];
        pools = ret[2];
        expect(chainIDs.length).equal(1);
        // expect(chainIDs[0]).equal(1313161554);
        expect(tokens[0]).equal(network_.Swap.WNEAR);
        expect(pools[0]).equal(0);
      });
    });

    describe('Basic function', () => {
      beforeEach(async () => {
        vault.connect(deployer).setAdmin(accounts[0].address);
        stVault.connect(deployer).setAdmin(accounts[0].address);
        admin = accounts[0];
      });

      it("Basic Deposit/withdraw with small amount", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        const l2stNEARVault = new ethers.Contract(await stVault.stNEARVault(), l2VaultArtifact.abi, a1);

        // deposit
        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdtAmount('50000')]);

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(100));

        expect(await usdt.balanceOf(a1.address)).equal(0);
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await usdt.balanceOf(strategy.address)).equal(0);

        ret = await priceOracle.getAssetPrice(network_.Swap.WNEAR);
        const WNEARPrice = ret[0];
        const WNEARPriceDecimals = ret[1];
        const WNEARAmt = getWNearAmount(1).mul(50000).div(WNEARPrice).mul(e(WNEARPriceDecimals));

        const WNEAR = new ethers.Contract(network_.Swap.WNEAR, ERC20_ABI, deployer);
        const WNEARDeposits = await WNEAR.balanceOf(stVault.address);
        expect(await WNEAR.balanceOf(strategy.address)).equal(0);
        expect(WNEARDeposits).closeTo(WNEARAmt, WNEARAmt.div(100));

        const cstNEAR = new ethers.Contract(network_.Bastion.cstNEAR1, ERC20_ABI, deployer);
        expect(await cstNEAR.balanceOf(l2stNEARVault.address)).equal(0);

        expect(await stVault.bufferedDeposits()).equal(WNEARDeposits);
        expect(await stVault.totalSupply()).equal(WNEARDeposits);
        expect(await l2stNEARVault.totalSupply()).equal(0);

        // invest
        await stVault.connect(admin).invest();

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(50));

        expect(await WNEAR.balanceOf(stVault.address)).equal(0);
        const stNEAR = new ethers.Contract(network_.Token.stNEAR, ERC20_ABI, deployer);
        expect(await stNEAR.balanceOf(stVault.address)).equal(0);
        expect(await stNEAR.balanceOf(l2stNEARVault.address)).equal(0);

        expect(await cstNEAR.balanceOf(l2stNEARVault.address)).gt(0);

        ret = await priceOracle.getAssetPrice(network_.Token.stNEAR);
        const stNEARPrice = ret[0];
        const stNEARPriceDecimals = ret[1];
        const stNEARAmt = getWNearAmount(1).mul(50000).div(stNEARPrice).mul(e(stNEARPriceDecimals));
        expect(await stVault.getInvestedStTokens()).closeTo(stNEARAmt, stNEARAmt.div(50));
        expect(await stVault.bufferedDeposits()).equal(0);

        expect(await stVault.totalSupply()).gt(0);
        const stNEARVaultShare = await l2stNEARVault.totalSupply();
        expect(stNEARVaultShare).gt(0);

        // withdraw all
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1'));
        let usdtBalance = await usdt.balanceOf(a1.address);
        expect(usdtBalance).gt(0); // Some stNEARs is not swapped to WNEAR because metaPool buffer is insufficient
        // expect(await nft.totalSupply()).equal(1);
        // expect(await nft.exists(1)).equal(true);
        // expect(await nft.isApprovedOrOwner(strategy.address, 1)).equal(true);
        // expect(await stVault.pendingRedeems()).gt(0);
        expect(await vault.getAllPoolInUSD()).equal(0);
        ret = await vault.getUnbondedAll(a1.address);
        let waitingInUSD = ret[0];
        let unbondedInUSD = ret[1];
        let waitForTs = ret[2];
        expect(waitingInUSD).equal(0);
        expect(unbondedInUSD).equal(0);
        expect(waitForTs).equal(0);
        expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(25));

        expect(await stVault.totalSupply()).equal(0);
        expect(await l2stNEARVault.totalSupply()).closeTo(stNEARVaultShare.div(50000), stNEARVaultShare.div(50000));
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await usdt.balanceOf(strategy.address)).equal(0);
        expect(await WNEAR.balanceOf(strategy.address)).equal(0);
        expect(await WNEAR.balanceOf(stVault.address)).equal(0);
        expect(await stNEAR.balanceOf(stVault.address)).closeTo(stNEARVaultShare.div(50000), stNEARVaultShare.div(50000));
        expect(await stNEAR.balanceOf(l2stNEARVault.address)).equal(0);
        expect(await cstNEAR.balanceOf(l2stNEARVault.address)).closeTo(stNEARVaultShare.div(50000), stNEARVaultShare.div(50000));
      });

      it("Deposit/withdraw by 2 people", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));
        await usdt.transfer(a2.address, getUsdtAmount('50000'));
        await usdt.connect(a2).approve(vault.address, getUsdtAmount('50000'));

        const l2stNEARVault = new ethers.Contract(await stVault.stNEARVault(), l2VaultArtifact.abi, a1);

        // deposit
        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdtAmount('50000')]);
        await stVault.connect(admin).invest();
        await vault.connect(admin).depositByAdmin(a2.address, tokens, [getUsdtAmount('50000')]);

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('100000'), parseEther('100000').div(100));

        ret = await priceOracle.getAssetPrice(network_.Swap.WNEAR);
        const WNEARPrice = ret[0];
        const WNEARPriceDecimals = ret[1];
        const WNEARAmt = getWNearAmount(1).mul(50000).div(WNEARPrice).mul(e(WNEARPriceDecimals));

        const WNEAR = new ethers.Contract(network_.Swap.WNEAR, ERC20_ABI, deployer);
        const WNEARDeposits = await WNEAR.balanceOf(stVault.address);
        expect(await WNEAR.balanceOf(strategy.address)).equal(0);
        expect(WNEARDeposits).closeTo(WNEARAmt, WNEARAmt.div(20));

        const cstNEAR = new ethers.Contract(network_.Bastion.cstNEAR1, ERC20_ABI, deployer);
        const cstNEARBalance = await cstNEAR.balanceOf(l2stNEARVault.address);
        expect(cstNEARBalance).gt(0);

        expect(await stVault.bufferedDeposits()).equal(WNEARDeposits);
        expect(await stVault.totalSupply()).closeTo(WNEARDeposits.mul(2), WNEARDeposits.mul(2).div(20));
        const l2TotalSupply = await l2stNEARVault.totalSupply();
        expect(l2TotalSupply).gt(0);

        // invest
        await increaseTime(5*60);
        await stVault.connect(admin).invest();

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('100000'), parseEther('100000').div(50));

        expect(await WNEAR.balanceOf(stVault.address)).equal(0);
        const stNEAR = new ethers.Contract(network_.Token.stNEAR, ERC20_ABI, deployer);
        expect(await stNEAR.balanceOf(stVault.address)).equal(0);
        expect(await stNEAR.balanceOf(l2stNEARVault.address)).equal(0);

        expect(await cstNEAR.balanceOf(l2stNEARVault.address)).closeTo(cstNEARBalance.mul(2), cstNEARBalance.mul(2).div(50));

        ret = await priceOracle.getAssetPrice(network_.Token.stNEAR);
        const stNEARPrice = ret[0];
        const stNEARPriceDecimals = ret[1];
        const stNEARAmt = getWNearAmount(1).mul(100000).div(stNEARPrice).mul(e(stNEARPriceDecimals));
        expect(await stVault.getInvestedStTokens()).closeTo(stNEARAmt, stNEARAmt.div(50));
        expect(await stVault.bufferedDeposits()).equal(0);

        expect(await l2stNEARVault.totalSupply()).closeTo(l2TotalSupply.mul(2), l2TotalSupply.mul(2).div(50));

        // deposit a little, but not invest
        await usdt.transfer(a2.address, getUsdtAmount('10000'));
        await usdt.connect(a2).approve(vault.address, getUsdtAmount('10000'));
        await vault.connect(admin).depositByAdmin(a2.address, tokens, [getUsdtAmount('10000')]);
        expect(await WNEAR.balanceOf(stVault.address)).gt(0);

        // withdraw all of a1's deposit
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(5).div(11));
        let usdtBalance = await usdt.balanceOf(a1.address);
        expect(usdtBalance).gt(0); // Some stNEARs is not swapped to WNEAR because metaPool buffer is insufficient
        // expect(await nft.totalSupply()).equal(1);
        // expect(await nft.exists(1)).equal(true);
        // expect(await nft.isApprovedOrOwner(strategy.address, 1)).equal(true);
        // expect(await stVault.pendingRedeems()).gt(0);
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('60000'), parseEther('60000').div(20));
        ret = await vault.getUnbondedAll(a1.address);
        let waitingInUSD = ret[0];
        let unbondedInUSD = ret[1];
        let waitForTs = ret[2];
        expect(waitingInUSD).equal(0);
        expect(unbondedInUSD).equal(0);
        expect(waitForTs).equal(0);
        expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(20));
        expect(await WNEAR.balanceOf(stVault.address)).equal(0);
        expect(await l2stNEARVault.totalSupply()).closeTo(l2TotalSupply.mul(6).div(5), l2TotalSupply.mul(6).div(5).div(25));

        // withdraw all
        await vault.connect(admin).withdrawPercByAdmin(a2.address, parseEther('1'));
        usdtBalance = await usdt.balanceOf(a2.address);
        expect(usdtBalance).gt(0); // Some stNEARs is not swapped to WNEAR because metaPool buffer is insufficient
        // expect(await nft.totalSupply()).equal(1);
        // expect(await nft.exists(1)).equal(true);
        // expect(await nft.isApprovedOrOwner(strategy.address, 1)).equal(true);
        // expect(await stVault.pendingRedeems()).gt(0);
        expect(await vault.getAllPoolInUSD()).equal(0);
        ret = await vault.getUnbondedAll(a2.address);
        waitingInUSD = ret[0];
        unbondedInUSD = ret[1];
        waitForTs = ret[2];
        expect(waitingInUSD).equal(0);
        expect(unbondedInUSD).equal(0);
        expect(waitForTs).equal(0);
        expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('60000'), getUsdtAmount('60000').div(20));

        expect(await stVault.totalSupply()).equal(0);
        expect(await l2stNEARVault.totalSupply()).closeTo(l2TotalSupply.div(50000), l2TotalSupply.div(50000));
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await usdt.balanceOf(strategy.address)).equal(0);
        expect(await WNEAR.balanceOf(strategy.address)).equal(0);
        expect(await WNEAR.balanceOf(stVault.address)).equal(0);
        expect(await stNEAR.balanceOf(stVault.address)).closeTo(l2TotalSupply.div(50000), l2TotalSupply.div(50000));
        expect(await stNEAR.balanceOf(l2stNEARVault.address)).equal(0);
        expect(await cstNEAR.balanceOf(l2stNEARVault.address)).closeTo(l2TotalSupply.div(50000), l2TotalSupply.div(50000));
      });

      it("emergencyWithdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));
        await usdt.transfer(a2.address, getUsdtAmount('50000'));
        await usdt.connect(a2).approve(vault.address, getUsdtAmount('50000'));

        const l2stNEARVault = new ethers.Contract(await stVault.stNEARVault(), l2VaultArtifact.abi, a1);

        // deposit
        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdtAmount('50000')]);
        await stVault.connect(admin).invest();
        await vault.connect(admin).depositByAdmin(a2.address, tokens, [getUsdtAmount('50000')]);

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('100000'), parseEther('100000').div(100));

        ret = await priceOracle.getAssetPrice(network_.Swap.WNEAR);
        const WNEARPrice = ret[0];
        const WNEARPriceDecimals = ret[1];
        const WNEARAmt = getWNearAmount(1).mul(50000).div(WNEARPrice).mul(e(WNEARPriceDecimals));

        const WNEAR = new ethers.Contract(network_.Swap.WNEAR, ERC20_ABI, deployer);
        const WNEARDeposits = await WNEAR.balanceOf(stVault.address);
        expect(await WNEAR.balanceOf(strategy.address)).equal(0);
        expect(WNEARDeposits).closeTo(WNEARAmt, WNEARAmt.div(20));

        const stNEAR = new ethers.Contract(network_.Token.stNEAR, ERC20_ABI, deployer);
        const cstNEAR = new ethers.Contract(network_.Bastion.cstNEAR1, ERC20_ABI, deployer);
        const cstNEARBalance = await cstNEAR.balanceOf(l2stNEARVault.address);
        expect(cstNEARBalance).gt(0);

        expect(await stVault.bufferedDeposits()).equal(WNEARDeposits);
        expect(await stVault.totalSupply()).closeTo(WNEARDeposits.mul(2), WNEARDeposits.mul(2).div(20));
        const l2TotalSupply = await l2stNEARVault.totalSupply();
        expect(l2TotalSupply).gt(0);

        // emergencyWithdraw before investment
        await vault.connect(admin).emergencyWithdraw();

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('100000'), parseEther('100000').div(50));

        expect(await stVault.totalSupply()).equal(0);
        expect(await l2stNEARVault.totalSupply()).closeTo(l2TotalSupply.div(50000), l2TotalSupply.div(50000));
        expect(await usdt.balanceOf(vault.address)).closeTo(getUsdtAmount('100000'), getUsdtAmount('100000').div(50));
        expect(await usdt.balanceOf(strategy.address)).equal(0);
        expect(await WNEAR.balanceOf(strategy.address)).equal(0);
        expect(await WNEAR.balanceOf(stVault.address)).equal(0);
        expect(await stNEAR.balanceOf(stVault.address)).closeTo(l2TotalSupply.div(50000), l2TotalSupply.div(50000));
        expect(await stNEAR.balanceOf(l2stNEARVault.address)).equal(0);
        expect(await cstNEAR.balanceOf(l2stNEARVault.address)).closeTo(l2TotalSupply.div(50000), l2TotalSupply.div(50000));

        // check if deposit is disabled
        await usdt.transfer(a2.address, getUsdtAmount('10000'));
        await usdt.connect(a2).approve(vault.address, getUsdtAmount('10000'));
        await expectRevert(vault.connect(admin).depositByAdmin(a2.address, tokens, [getUsdtAmount('10000')]), "Pausable: paused");

        // withdraw all of a1's deposit
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').div(2));
        let usdtBalance = await usdt.balanceOf(a1.address);
        expect(usdtBalance).gt(0); // Some stNEARs is not swapped to WNEAR because metaPool buffer is insufficient
        // expect(await nft.totalSupply()).equal(1);
        // expect(await nft.exists(1)).equal(true);
        // expect(await nft.isApprovedOrOwner(strategy.address, 1)).equal(true);
        // expect(await stVault.pendingRedeems()).gt(0);
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(20));
        ret = await vault.getUnbondedAll(a1.address);
        let waitingInUSD = ret[0];
        let unbondedInUSD = ret[1];
        let waitForTs = ret[2];
        expect(waitingInUSD).equal(0);
        expect(unbondedInUSD).equal(0);
        expect(waitForTs).equal(0);
        expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(20));

        // reinvest
        ret = await vault.getCurrentCompositionPerc();
        await vault.connect(admin).reinvest(ret[0], ret[1]);

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(20));
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await WNEAR.balanceOf(stVault.address)).closeTo(WNEARDeposits, WNEARDeposits.div(20));
        expect(await stVault.bufferedDeposits()).equal(await WNEAR.balanceOf(stVault.address));
        expect(await stVault.totalSupply()).closeTo(WNEARDeposits, WNEARDeposits.div(20));

        await increaseTime(5*60);
        await stVault.connect(admin).invest();
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(20));
        expect(await WNEAR.balanceOf(stVault.address)).equal(0);
        expect(await stNEAR.balanceOf(stVault.address)).equal(0);
        expect(await stNEAR.balanceOf(l2stNEARVault.address)).equal(0);
        expect(await cstNEAR.balanceOf(l2stNEARVault.address)).closeTo(cstNEARBalance, cstNEARBalance.div(20));
        expect(await l2stNEARVault.totalSupply()).closeTo(l2TotalSupply, l2TotalSupply.div(20));
      });
    });

    describe('StVault', () => {
      beforeEach(async () => {
        vault.connect(deployer).setAdmin(accounts[0].address);
        stVault.connect(deployer).setAdmin(accounts[0].address);
        admin = accounts[0];
      });

      it("emergencyWithdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        const l2stNEARVault = new ethers.Contract(await stVault.stNEARVault(), l2VaultArtifact.abi, a1);
        const WNEAR = new ethers.Contract(network_.Swap.WNEAR, ERC20_ABI, deployer);
        const stNEAR = new ethers.Contract(network_.Token.stNEAR, ERC20_ABI, deployer);
        const cstNEAR = new ethers.Contract(network_.Bastion.cstNEAR1, ERC20_ABI, deployer);

        // deposit & invest
        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdtAmount('50000')]);
        await stVault.connect(admin).invest();

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(50));
        expect(await WNEAR.balanceOf(stVault.address)).equal(0);
        expect(await cstNEAR.balanceOf(l2stNEARVault.address)).gt(0);
        const stNEARVaultShare = await l2stNEARVault.totalSupply();

        // emergency on stVault
        await stVault.connect(admin).emergencyWithdraw();

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(50));
        expect(await WNEAR.balanceOf(stVault.address)).gt(0);
        expect(await cstNEAR.balanceOf(l2stNEARVault.address)).equal(0);

        // withdraw 40%
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(2).div(5));
        let usdtBalance = await usdt.balanceOf(a1.address);
        expect(usdtBalance).gt(0); // Some stNEARs is not swapped to WNEAR because metaPool buffer is insufficient
        // expect(await nft.totalSupply()).equal(1);
        // expect(await nft.exists(1)).equal(true);
        // expect(await nft.isApprovedOrOwner(strategy.address, 1)).equal(true);
        // expect(await stVault.pendingRedeems()).gt(0);
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('30000'), parseEther('30000').div(50));
        ret = await vault.getUnbondedAll(a1.address);
        let waitingInUSD = ret[0];
        let unbondedInUSD = ret[1];
        let waitForTs = ret[2];
        expect(waitingInUSD).equal(0);
        expect(unbondedInUSD).equal(0);
        expect(waitForTs).equal(0);
        expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('20000'), getUsdtAmount('20000').div(50));

        // reinvest on stVault
        await stVault.connect(admin).reinvest();

        // withdraw all
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1'));
        usdtBalance = await usdt.balanceOf(a1.address);
        expect(usdtBalance).gt(0); // Some stNEARs is not swapped to WNEAR because metaPool buffer is insufficient
        // expect(await nft.totalSupply()).equal(1);
        // expect(await nft.exists(1)).equal(true);
        // expect(await nft.isApprovedOrOwner(strategy.address, 1)).equal(true);
        // expect(await stVault.pendingRedeems()).gt(0);
        expect(await vault.getAllPoolInUSD()).equal(0);
        ret = await vault.getUnbondedAll(a1.address);
        waitingInUSD = ret[0];
        unbondedInUSD = ret[1];
        waitForTs = ret[2];
        expect(waitingInUSD).equal(0);
        expect(unbondedInUSD).equal(0);
        expect(waitForTs).equal(0);
        expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(50));

        expect(await stVault.totalSupply()).equal(0);
        expect(await l2stNEARVault.totalSupply()).closeTo(stNEARVaultShare.div(50000), stNEARVaultShare.div(50000));
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await usdt.balanceOf(strategy.address)).equal(0);
        expect(await WNEAR.balanceOf(strategy.address)).equal(0);
        expect(await WNEAR.balanceOf(stVault.address)).equal(0);
        expect(await stNEAR.balanceOf(stVault.address)).closeTo(stNEARVaultShare.div(50000), stNEARVaultShare.div(50000));
        expect(await stNEAR.balanceOf(l2stNEARVault.address)).equal(0);
        expect(await cstNEAR.balanceOf(l2stNEARVault.address)).closeTo(stNEARVaultShare.div(50000), stNEARVaultShare.div(50000));
      });
    });

    describe('Enable the Bastion supply reward for cstNEAR', () => {
      let cstNEAR, BSTN, META;

      beforeEach(async () => {
        vault.connect(deployer).setAdmin(accounts[0].address);
        stVault.connect(deployer).setAdmin(accounts[0].address);
        admin = accounts[0];

        cstNEAR = new ethers.Contract(network_.Bastion.cstNEAR1, ERC20_ABI, deployer);
        BSTN = new ethers.Contract('0x9f1F933C660a1DC856F0E0Fe058435879c5CCEf0', ERC20_ABI, deployer);
        META = new ethers.Contract('0xc21Ff01229e982d7c8b8691163B0A3Cb8F357453', ERC20_ABI, deployer);
      });

      it("Yield on L2 vault", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('5000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('5000'));

        const l2stNEARVault = new ethers.Contract(await stVault.stNEARVault(), l2VaultArtifact.abi, a1);
        await l2stNEARVault.connect(deployer).setAdmin(admin.address);

        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdtAmount('5000')]);
        await stVault.connect(admin).invest();

        expect(await l2stNEARVault.getPendingRewards()).equal(0);
        const balanceBefore = await cstNEAR.balanceOf(l2stNEARVault.address);
        expect(await BSTN.balanceOf(common.treasury)).equal(0);
        expect(await META.balanceOf(common.treasury)).equal(0);

        await increaseTime(DAY);
        expect(await l2stNEARVault.getPendingRewards()).gt(0);
        await l2stNEARVault.connect(admin).yield();
        expect(await l2stNEARVault.getPendingRewards()).equal(0);
        expect(await cstNEAR.balanceOf(l2stNEARVault.address)).gt(balanceBefore);
        expect(await BSTN.balanceOf(l2stNEARVault.address)).equal(0);
        expect(await BSTN.balanceOf(common.treasury)).gt(0);
        expect(await META.balanceOf(l2stNEARVault.address)).equal(0);
        expect(await META.balanceOf(common.treasury)).gt(0);
      });
    });
});