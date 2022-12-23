const { expect } = require("chai");
const { assert, ethers, deployments } = require("hardhat");
const { expectRevert } = require('@openzeppelin/test-helpers');
const { BigNumber } = ethers;
const parseEther = ethers.utils.parseEther;
const { increaseTime, etherBalance, sendValue } = require("../../scripts/utils/ethereum");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable.json").abi;
const AvalanchePool_ABI = [
  "function serveClaims(address payable residueAddress, uint256 minThreshold) external payable",
];

const { common, avaxMainnet: network_ } = require("../../parameters");

const DAY = 24 * 3600;

function getUsdVaule(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}
function getUsdtAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}
function getAvaxAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(18))
}
function e(decimals) {
  return BigNumber.from(10).pow(decimals)
}

const avalanchePoolAdminAddr = '0x2Ffc59d32A524611Bb891cab759112A51f9e33C0';

async function serveClaims() {
  const avalanchePoolAdmin = await ethers.getSigner(avalanchePoolAdminAddr);
  const avalanchePool = new ethers.Contract('0x7BAa1E3bFe49db8361680785182B80BB420A836D', AvalanchePool_ABI, avalanchePoolAdmin);

  const value = (await etherBalance(avalanchePoolAdmin.address)).sub(parseEther('1'));
  await avalanchePool.serveClaims(avalanchePoolAdmin.address, 0, {value: value});
}

describe("STI on Avalanche", async () => {

    let sti, minter, vault, strategy, stVault, priceOracle, usdt, nft;
    let stiArtifact, minterArtifact, vaultArtifact, strategyArtifact, stVaultArtifact, priceOracleArtifact, nftArtifact;
    let admin;

    before(async () => {
      [deployer, a1, a2, ...accounts] = await ethers.getSigners();
  
      stiArtifact = await deployments.getArtifact("STI");
      minterArtifact = await deployments.getArtifact("STIMinter");
      vaultArtifact = await deployments.getArtifact("STIVault");
      strategyArtifact = await deployments.getArtifact("AvaxSTIStrategy");
      stVaultArtifact = await deployments.getArtifact("AvaxStAVAXVault");
      nftArtifact = await deployments.getArtifact("StVaultNFT");
      priceOracleArtifact = await deployments.getArtifact("AvaxPriceOracle");
    });

    beforeEach(async () => {
      await deployments.fixture(["hardhat_avax_sti"])

      const stiProxy = await ethers.getContract("STI_Proxy");
      sti = new ethers.Contract(stiProxy.address, stiArtifact.abi, a1);
      const minterProxy = await ethers.getContract("STIMinter_Proxy");
      minter = new ethers.Contract(minterProxy.address, minterArtifact.abi, a1);
      const vaultProxy = await ethers.getContract("STIVault_Proxy");
      vault = new ethers.Contract(vaultProxy.address, vaultArtifact.abi, a1);
      const strategyProxy = await ethers.getContract("AvaxSTIStrategy_Proxy");
      strategy = new ethers.Contract(strategyProxy.address, strategyArtifact.abi, a1);
      stVault = new ethers.Contract(await strategy.AVAXVault(), stVaultArtifact.abi, a1);
      nft = new ethers.Contract(await stVault.nft(), nftArtifact.abi, a1);
      const priceOracleProxy = await ethers.getContract("AvaxPriceOracle_Proxy");
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

        expect(await sti.owner()).equal(deployer.address);
        expect(await sti.name()).equal('Staking Index Fund');
        expect(await sti.symbol()).equal('STI');
        expect(await sti.minter()).equal(minter.address);

        expect(await minter.owner()).equal(deployer.address);
        expect(await minter.admin()).equal(common.admin);
        expect(await minter.trustedForwarder()).equal(network_.biconomy);
        expect(await minter.STI()).equal(sti.address);
        expect(await minter.priceOracle()).equal(priceOracle.address);
        expect(await minter.chainIDs(0)).equal(1);
        expect(await minter.chainIDs(1)).equal(1);
        expect(await minter.chainIDs(2)).equal(56);
        expect(await minter.chainIDs(3)).equal(43114);
        expect(await minter.chainIDs(4)).equal(1313161554);
        expect(await minter.tokens(0)).equal(common.nativeAsset);
        expect(await minter.tokens(1)).equal('0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0');
        expect(await minter.tokens(2)).equal(common.nativeAsset);
        expect(await minter.tokens(3)).equal(common.nativeAsset);
        expect(await minter.tokens(4)).equal('0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d');
        expect(await minter.targetPercentages(0)).equal(2000);
        expect(await minter.targetPercentages(1)).equal(2000);
        expect(await minter.targetPercentages(2)).equal(2000);
        expect(await minter.targetPercentages(3)).equal(2000);
        expect(await minter.targetPercentages(4)).equal(2000);
        expect(await minter.tid(1, common.nativeAsset)).equal(0);
        expect(await minter.tid(1, '0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0')).equal(1);
        expect(await minter.tid(56, common.nativeAsset)).equal(2);
        expect(await minter.tid(43114, common.nativeAsset)).equal(3);
        expect(await minter.tid(1313161554, '0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d')).equal(4);
        expect(await minter.getNonce()).equal(0);

        expect(await vault.owner()).equal(deployer.address);
        expect(await vault.admin()).equal(common.admin);
        expect(await vault.trustedForwarder()).equal(network_.biconomy);
        expect(await vault.strategy()).equal(strategy.address);
        expect(await vault.priceOracle()).equal(priceOracle.address);
        expect(await vault.USDT()).equal(network_.Swap.USDT);

        expect(await strategy.owner()).equal(deployer.address);
        expect(await strategy.admin()).equal(common.admin);
        expect(await strategy.vault()).equal(vault.address);
        expect(await strategy.priceOracle()).equal(priceOracle.address);
        expect(await strategy.router()).equal('0x60aE616a2155Ee3d9A68541Ba4544862310933d4');
        expect(await strategy.SWAP_BASE_TOKEN()).equal(network_.Swap.WAVAX);
        expect(await strategy.USDT()).equal(network_.Swap.USDT);
        expect(await strategy.tokens(0)).equal(common.nativeAsset);
        expect(await strategy.pid(common.nativeAsset)).equal(0);

        expect(await stVault.name()).equal('STI Staking AVAX');
        expect(await stVault.symbol()).equal('stiStAVAX');
        expect(await stVault.treasuryWallet()).equal(common.treasury);
        expect(await stVault.admin()).equal(common.admin);
        expect(await stVault.priceOracle()).equal(priceOracle.address);
        expect(await stVault.yieldFee()).equal(2000);
        expect(await stVault.nft()).equal(await nftFactory.getNFTByVault(stVault.address));
        expect(await stVault.token()).equal(common.nativeAsset);
        expect(await stVault.stToken()).equal(network_.Token.aAVAXb);
      });

      it("Should be set by only owner", async () => {
        await expectRevert(priceOracle.setAssetSources([a2.address],[a1.address]), "Ownable: caller is not the owner");

        await expectRevert(sti.setMinter(a2.address), "Ownable: caller is not the owner");
        await expectRevert(sti.mint(a2.address, parseEther('1')), "Mintable: caller is not the minter");

        await expectRevert(minter.setAdmin(a2.address), "Ownable: caller is not the owner");
        await expectRevert(minter.setBiconomy(a2.address), "Ownable: caller is not the owner");
        await expectRevert(minter.setGatewaySigner(a2.address), "Ownable: caller is not the owner");
        await expectRevert(minter.addToken(1, a1.address), "Ownable: caller is not the owner");
        await expectRevert(minter.removeToken(1), "Ownable: caller is not the owner");
        await expectRevert(minter.setTokenCompositionTargetPerc([10000]), "Ownable: caller is not the owner");
        await expect(minter.initDepositByAdmin(a1.address, await vault.getAllPoolInUSD(), getUsdtAmount('100'))).to.be.reverted; //With(/AccessControl: account .* is missing role .*/);
        await expect(minter.mintByAdmin(a1.address, 0)).to.be.reverted;
        await expect(minter.burnByAdmin(a1.address, getUsdtAmount('100'))).to.be.reverted;
        await expect(minter.exitWithdrawalByAdmin(a1.address)).to.be.reverted;

        await expectRevert(vault.setAdmin(a2.address), "Ownable: caller is not the owner");
        await expectRevert(vault.setBiconomy(a2.address), "Ownable: caller is not the owner");
        await expectRevert(vault.depositByAdmin(a1.address, [a2.address], [getUsdtAmount('100')], 1), "Only owner or admin");
        await expectRevert(vault.withdrawPercByAdmin(a1.address, parseEther('0.1'), 1), "Only owner or admin");
        await expectRevert(vault.claimByAdmin(a1.address), "Only owner or admin");
        await expectRevert(vault.emergencyWithdraw(), "Only owner or admin");
        await expectRevert(vault.claimEmergencyWithdrawal(), "Only owner or admin");
        await expectRevert(vault.reinvest([a2.address], [10000]), "Only owner or admin");
        await expectRevert(vault.setStrategy(a2.address), "Ownable: caller is not the owner");

        await expectRevert(strategy.addToken(a1.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.removeToken(1), "Ownable: caller is not the owner");
        await expectRevert(strategy.setAdmin(a2.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.setVault(a2.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.setStVault(a2.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.invest([a2.address], [getUsdVaule('100')]), "Only vault");
        await expectRevert(strategy.withdrawPerc(a2.address, 1), "Only vault");
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
        expect(await stVault.minInvestAmount()).equal(parseEther('1'));
        expect(await stVault.minRedeemAmount()).equal(6);
        await stVault.connect(deployer).setStakingAmounts(1,1);

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
        expect(await vault.getAPR()).equal(0); // Because there is no L2 vault
        expect(await vault.getAllPoolInUSD()).equal(0);

        var ret = await vault.getEachPoolInUSD();
        chainIDs = ret[0];
        tokens = ret[1];
        pools = ret[2];
        expect(chainIDs.length).equal(1);
        // expect(chainIDs[0]).equal(1313161554);
        expect(tokens[0]).equal(common.nativeAsset);
        expect(pools[0]).equal(0);
      });
    });

    describe('Basic function', () => {
      it("Basic Deposit/withdraw with small amount", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        const aAVAXb = new ethers.Contract(network_.Token.aAVAXb, ERC20_ABI, deployer);

        var pool = await vault.getAllPoolInUSD();
        await minter.connect(admin).initDepositByAdmin(a1.address, pool, getUsdtAmount('50000'));
        await expectRevert(minter.connect(admin).initDepositByAdmin(a1.address, pool, getUsdtAmount('50000')), "Previous operation not finished");
        expect(await minter.getNonce()).equal(1);
        expect(await minter.userLastOperationNonce(a1.address)).equal(1);
        ret = await minter.getOperation(1);
        expect(ret[0]).equal(a1.address);
        expect(ret[1]).equal(1);
        expect(ret[2]).equal(false);
        expect(ret[3]).equal(pool);
        expect(ret[4]).equal(getUsdtAmount('50000'));

        // deposit
        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        var avaxPool = await vault.getAllPoolInUSD()
        await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdVaule('50000')], 1);
        await expectRevert(vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdVaule('50000')], 1), "Nonce is behind");
        expect(await vault.firstOperationNonce()).equal(1);
        expect(await vault.lastOperationNonce()).equal(1);
        ret = await vault.poolAtNonce(1);
        expect(ret[0]).equal(avaxPool);
        expect(ret[1]).gt(0);
        expect(await vault.userLastOperationNonce(a1.address)).equal(1);
        expect(await vault.operationAmounts(1)).closeTo(parseEther('50000'), parseEther('50000').div(100));

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(100));

        expect(await usdt.balanceOf(a1.address)).equal(0);
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await usdt.balanceOf(strategy.address)).equal(0);

        ret = await priceOracle.getAssetPrice(common.nativeAsset);
        const AVAXPrice = ret[0];
        const AVAXPriceDecimals = ret[1];
        const AVAXAmt = getAvaxAmount(1).mul(50000).div(AVAXPrice).mul(e(AVAXPriceDecimals));

        const AVAXDeposits = await etherBalance(stVault.address);
        expect(await etherBalance(strategy.address)).equal(0);
        expect(AVAXDeposits).closeTo(AVAXAmt, AVAXAmt.div(100));

        expect(await stVault.bufferedDeposits()).equal(AVAXDeposits);
        expect(await stVault.totalSupply()).equal(AVAXDeposits);

        // invest
        await stVault.connect(admin).invest();

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(50));
        expect(await etherBalance(stVault.address)).lt(parseEther('1'));

        const aAVAXbAmt = await stVault.getStTokenByPooledToken(AVAXDeposits);
        const aAVAXbBalance = await aAVAXb.balanceOf(stVault.address);
        expect(aAVAXbBalance).closeTo(aAVAXbAmt, aAVAXbAmt.div(50));
        expect(await stVault.getInvestedStTokens()).equal(0);
        expect(await stVault.bufferedDeposits()).lt(parseEther('1'));
        expect(await stVault.totalSupply()).equal(AVAXDeposits);

        // withdraw all
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1'), 2);
        let usdtBalance = await usdt.balanceOf(a1.address);
        expect(usdtBalance).gte(0);
        expect(await stVault.bufferedDeposits()).equal(0);
        expect(await nft.totalSupply()).equal(1);
        expect(await nft.exists(1)).equal(true);
        expect(await nft.isApprovedOrOwner(strategy.address, 1)).equal(true);
        expect(await stVault.pendingRedeems()).closeTo(aAVAXbBalance, aAVAXbBalance.div(100));
        expect(await stVault.pendingWithdrawals()).closeTo(AVAXDeposits, AVAXDeposits.div(100));
        expect(await vault.getAllPoolInUSD()).equal(0);
        ret = await vault.getAllUnbonded(a1.address);
        let waitingInUSD = ret[0];
        let unbondedInUSD = ret[1];
        let waitForTs = ret[2];
        expect(waitingInUSD).gt(0);
        expect(unbondedInUSD).equal(0);
        const unbondingPeriod = await stVault.unbondingPeriod();
        expect(waitForTs).closeTo(unbondingPeriod, unbondingPeriod.div(100));
        expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(100));

        ret = await vault.getAllUnbonded(a2.address);
        expect(ret[0]).equal(0);
        expect(ret[1]).equal(0);
        expect(ret[2]).equal(0);

        var ret = await vault.getPoolsUnbonded(a1.address);
        chainIDs = ret[0];
        tokens = ret[1];
        waitings = ret[2];
        waitingInUSDs = ret[3];
        unbondeds = ret[4];
        unbondedInUSDs = ret[5];
        waitForTses = ret[6];
        expect(chainIDs.length).equal(1);
        expect(tokens[0]).equal(common.nativeAsset);
        expect(waitings[0]).gt(0);
        expect(waitingInUSDs[0]).gt(0);
        expect(unbondeds[0]).equal(0);
        expect(unbondedInUSDs[0]).equal(0);
        expect(waitForTses[0]).closeTo(unbondingPeriod, unbondingPeriod.div(100));

        var ret = await vault.getAllUnbonded(a1.address);
        expect(waitingInUSDs[0]).equal(ret[0]);
        expect(unbondedInUSDs[0]).equal(ret[1]);
        expect(waitForTses[0]).equal(ret[2]);

        // redeem on stVault
        await stVault.connect(admin).redeem();
        expect(await stVault.pendingRedeems()).equal(0);
        expect(await stVault.pendingWithdrawals()).closeTo(AVAXDeposits, AVAXDeposits.div(100));
        expect(await aAVAXb.balanceOf(stVault.address)).closeTo(BigNumber.from(10), 10);

        // try before the end of unbonding. it should be failed.
        await increaseTime(waitForTs-10);
        await vault.connect(admin).claimByAdmin(a1.address);
        expect(await usdt.balanceOf(a1.address)).equal(usdtBalance); // no claimed
        await vault.connect(a1).claim();
        expect(await usdt.balanceOf(a1.address)).equal(usdtBalance); // no claimed

        await increaseTime(10);
        await vault.connect(a2).claim();
        expect(await usdt.balanceOf(a2.address)).equal(0); // no claimed

        // Even though the unbundoing period is over, it's not claimable if no token claimed in stVault
        ret = await vault.getAllUnbonded(a1.address);
        expect(ret[0]).gt(0);
        expect(ret[1]).equal(0);
        expect(ret[2]).equal(0);

        expect(await stVault.getTokenUnbonded()).equal(0);

        // transfer AVAX to the stVault instead avalanchePool.
        const UnstakedAmt = await stVault.getPooledTokenByStToken(aAVAXbBalance);
        await sendValue(avalanchePoolAdminAddr, stVault.address, UnstakedAmt);
        ret = await vault.getAllUnbonded(a1.address);
        expect(ret[0]).equal(0);
        expect(ret[1]).gt(0);
        expect(ret[2]).equal(0);

        // claim the unbonded on stVault;
        await vault.connect(a1).claim();
        expect(await stVault.pendingWithdrawals()).equal(0);
        expect(await etherBalance(stVault.address)).equal(0);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(100));

        ret = await vault.getAllUnbonded(a1.address);
        expect(ret[0]).equal(0);
        expect(ret[1]).equal(0);
        expect(ret[2]).equal(0);
        expect(await nft.totalSupply()).equal(0);

        expect(await stVault.totalSupply()).equal(0);
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await usdt.balanceOf(strategy.address)).equal(0);
        expect(await etherBalance(strategy.address)).equal(0);
        expect(await etherBalance(stVault.address)).equal(0);
        expect(await aAVAXb.balanceOf(stVault.address)).closeTo(BigNumber.from(10), 10);
      });

      it("emergencyWithdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));
        await usdt.transfer(a2.address, getUsdtAmount('50000'));
        await usdt.connect(a2).approve(vault.address, getUsdtAmount('50000'));

        const aAVAXb = new ethers.Contract(network_.Token.aAVAXb, ERC20_ABI, deployer);

        // deposit
        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await minter.connect(admin).initDepositByAdmin(a1.address, await vault.getAllPoolInUSD(), getUsdtAmount('50000'));
        await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdVaule('50000')], 1);
        await minter.connect(admin).mintByAdmin(a1.address, getUsdtAmount('50000'));
        await stVault.connect(admin).invest();
        await minter.connect(admin).initDepositByAdmin(a2.address, await vault.getAllPoolInUSD(), getUsdtAmount('50000'));
        await vault.connect(admin).depositByAdmin(a2.address, tokens, [getUsdVaule('50000')], 2);
        await minter.connect(admin).mintByAdmin(a2.address, getUsdtAmount('50000'));

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('100000'), parseEther('100000').div(50));

        ret = await priceOracle.getAssetPrice(common.nativeAsset);
        const AVAXPrice = ret[0];
        const AVAXPriceDecimals = ret[1];
        const AVAXAmt = getAvaxAmount(1).mul(50000).div(AVAXPrice).mul(e(AVAXPriceDecimals));

        const AVAXDeposits = await etherBalance(stVault.address);
        expect(await etherBalance(strategy.address)).equal(0);
        expect(AVAXDeposits).closeTo(AVAXAmt, AVAXAmt.div(25));

        expect(await stVault.bufferedDeposits()).equal(AVAXDeposits);
        expect(await stVault.totalSupply()).closeTo(AVAXDeposits.mul(2), AVAXDeposits.mul(2).div(50));

        const aAVAXbAmt = await stVault.getStTokenByPooledToken(AVAXDeposits);
        const aAVAXbBalance = await aAVAXb.balanceOf(stVault.address);
        expect(aAVAXbBalance).closeTo(aAVAXbAmt, aAVAXbAmt.div(50));

        // emergencyWithdraw before investment
        await vault.connect(admin).emergencyWithdraw();

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('100000'), parseEther('100000').div(50));
        expect(await stVault.totalSupply()).equal(0);
        expect(await stVault.pendingRedeems()).closeTo(aAVAXbBalance, aAVAXbBalance.div(100));
        expect(await stVault.pendingWithdrawals()).closeTo(AVAXDeposits, AVAXDeposits.div(50));
        expect(await usdt.balanceOf(vault.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(50));
        expect(await nft.totalSupply()).equal(1);

        ret = await vault.getEmergencyWithdrawalUnbonded();
        let waitingInUSD = ret[0];
        let unbondedInUSD = ret[1];
        let waitForTs = ret[2];
        expect(waitingInUSD).closeTo(parseEther('50000'), parseEther('50000').div(50));
        expect(unbondedInUSD).equal(0);
        const unbondingPeriod = await stVault.unbondingPeriod();
        expect(waitForTs).closeTo(unbondingPeriod, unbondingPeriod.div(100));

        await expectRevert(vault.connect(admin).depositByAdmin(a2.address, tokens, [getUsdVaule('10000')], 3), "Pausable: paused");
        await expectRevert(vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(2).div(3), 3), "Retry after all claimed");

        // withdraw a little of amount
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').div(10), 3);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('10000'), getUsdtAmount('10000').div(50));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('90000'), parseEther('90000').div(50));

        // redeem on stVault
        await stVault.connect(admin).redeem();

        await increaseTime(unbondingPeriod.toNumber());
        // transfer AVAX to the stVault instead binancePool.
        const UnstakedAmt = await stVault.getPooledTokenByStToken(aAVAXbBalance);
        await sendValue(avalanchePoolAdminAddr, stVault.address, UnstakedAmt);

        ret = await vault.getEmergencyWithdrawalUnbonded();
        waitingInUSD = ret[0];
        unbondedInUSD = ret[1];
        waitForTs = ret[2];
        expect(waitingInUSD).equal(0);
        expect(unbondedInUSD).closeTo(parseEther('50000'), parseEther('50000').div(50));
        expect(waitForTs).equal(0);

        // claim the emergency withdrawal
        await vault.connect(admin).claimEmergencyWithdrawal();

        ret = await vault.getEmergencyWithdrawalUnbonded();
        expect(ret[1]).equal(0);
        expect(await stVault.pendingRedeems()).equal(0);
        expect(await stVault.pendingWithdrawals()).equal(0);
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('90000'), parseEther('90000').div(50));
        expect(await usdt.balanceOf(vault.address)).closeTo(getUsdtAmount('90000'), getUsdtAmount('90000').div(50));
        expect(await nft.totalSupply()).equal(0);

        // withdraw rest of a1's deposit
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(4).div(9), 4);
        expect(await nft.totalSupply()).equal(0);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(25));
        expect(await usdt.balanceOf(vault.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(50));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(50));

        // reinvest
        ret = await vault.getCurrentCompositionPerc();
        await vault.connect(admin).reinvest(ret[0], ret[1]);

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(20));
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await etherBalance(stVault.address)).closeTo(AVAXDeposits, AVAXDeposits.div(20));
        expect(await stVault.bufferedDeposits()).equal(await etherBalance(stVault.address));
        expect(await stVault.totalSupply()).closeTo(AVAXDeposits, AVAXDeposits.div(20));

        await increaseTime(5*60);
        await stVault.connect(admin).invest();
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(20));
        expect(await etherBalance(stVault.address)).lt(parseEther('1'));
        expect(await aAVAXb.balanceOf(stVault.address)).closeTo(aAVAXbBalance, aAVAXbBalance.div(100));
      });
    });

    describe('StVault', () => {
      it("emergencyWithdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        const aAVAXb = new ethers.Contract(network_.Token.aAVAXb, ERC20_ABI, deployer);

        // deposit & invest
        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await minter.connect(admin).initDepositByAdmin(a1.address, await vault.getAllPoolInUSD(), getUsdtAmount('50000'));
        await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdVaule('50000')], 1);
        const AVAXDeposits = await etherBalance(stVault.address);

        await stVault.connect(admin).invest();

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(50));
        expect(await etherBalance(stVault.address)).lt(parseEther('1'));
        const aAVAXbBalance = await aAVAXb.balanceOf(stVault.address);

        // emergency on stVault
        await stVault.connect(admin).emergencyWithdraw();

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(50));
        expect(await etherBalance(stVault.address)).gt(0);
        expect(await aAVAXb.balanceOf(stVault.address)).closeTo(BigNumber.from(1), 1);
        expect(await stVault.pendingWithdrawals()).equal(0);
        expect(await stVault.totalSupply()).equal(AVAXDeposits);
        expect(await stVault.getEmergencyUnbondings()).equal(aAVAXbBalance);

        // withdraw 20000 USD
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(2).div(5), 2);
        let usdtBalance = await usdt.balanceOf(a1.address);
        expect(usdtBalance).gte(0);
        expect(await nft.totalSupply()).equal(1);
        expect(await nft.exists(1)).equal(true);
        expect(await nft.isApprovedOrOwner(strategy.address, 1)).equal(true);
        expect(await stVault.pendingRedeems()).equal(0);
        expect(await stVault.pendingWithdrawals()).closeTo(AVAXDeposits.mul(2).div(5), AVAXDeposits.mul(2).div(5).div(50));
        expect(await stVault.totalSupply()).closeTo(AVAXDeposits.mul(3).div(5), AVAXDeposits.mul(3).div(5).div(50));
        expect(await stVault.getEmergencyUnbondings()).closeTo(aAVAXbBalance.mul(3).div(5), aAVAXbBalance.mul(3).div(5).div(50));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('30000'), parseEther('30000').div(50));
        ret = await vault.getAllUnbonded(a1.address);
        let waitingInUSD = ret[0];
        let unbondedInUSD = ret[1];
        let waitForTs = ret[2];
        expect(waitingInUSD).closeTo(parseEther('20000'), parseEther('20000').div(50));
        expect(unbondedInUSD).equal(0);
        expect(waitForTs).gt(0);
        expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('20000'), getUsdtAmount('20000').div(50));

        // withdraw again 20000 USD
        await increaseTime(DAY);
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(2).div(3), 3);
        expect(await nft.totalSupply()).equal(2);
        expect(await nft.exists(2)).equal(true);
        expect(await nft.isApprovedOrOwner(strategy.address, 2)).equal(true);
        expect(await stVault.pendingRedeems()).equal(0);
        expect(await stVault.pendingWithdrawals()).closeTo(AVAXDeposits.mul(4).div(5), AVAXDeposits.mul(4).div(5).div(50));
        expect(await stVault.totalSupply()).closeTo(AVAXDeposits.div(5), AVAXDeposits.div(5).div(50));
        expect(await stVault.getEmergencyUnbondings()).closeTo(aAVAXbBalance.div(5), aAVAXbBalance.div(5).div(50));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('10000'), parseEther('10000').div(50));
        ret = await vault.getAllUnbonded(a1.address);
        waitingInUSD = ret[0];
        unbondedInUSD = ret[1];
        expect(waitingInUSD).closeTo(parseEther('40000'), parseEther('40000').div(50));
        expect(unbondedInUSD).equal(0);
        expect(ret[2]).lt(waitForTs);
        expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('40000'), getUsdtAmount('40000').div(50));

        await expectRevert(stVault.connect(admin).reinvest(), "Emergency unbonding is not finished");

        // // reinvest on stVault
        // await stVault.connect(admin).reinvest();

        // // withdraw all
        // await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1'), 4);
        // usdtBalance = await usdt.balanceOf(a1.address);
        // expect(usdtBalance).gt(0); // Some aAVAXbs is not swapped to WNEAR because metaPool buffer is insufficient
        // // expect(await nft.totalSupply()).equal(1);
        // // expect(await nft.exists(1)).equal(true);
        // // expect(await nft.isApprovedOrOwner(strategy.address, 1)).equal(true);
        // // expect(await stVault.pendingRedeems()).gt(0);
        // expect(await vault.getAllPoolInUSD()).equal(0);
        // ret = await vault.getAllUnbonded(a1.address);
        // waitingInUSD = ret[0];
        // unbondedInUSD = ret[1];
        // waitForTs = ret[2];
        // expect(waitingInUSD).equal(0);
        // expect(unbondedInUSD).equal(0);
        // expect(waitForTs).equal(0);
        // expect(usdtBalance.add(waitingInUSD.div(e(12))))).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(50));

        // expect(await stVault.totalSupply()).equal(0);
        // expect(await usdt.balanceOf(vault.address)).equal(0);
        // expect(await usdt.balanceOf(strategy.address)).equal(0);
        // expect(await etherBalance(strategy.address)).equal(0);
        // expect(await etherBalance(stVault.address)).equal(0);
        // expect(await aAVAXb.balanceOf(stVault.address)).closeTo(aAVAXbVaultShare.div(50000), aAVAXbVaultShare.div(50000));
      });
    });

});