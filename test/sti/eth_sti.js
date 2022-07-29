const { expect } = require("chai");
const { assert, ethers, deployments } = require("hardhat");
const { expectRevert } = require('@openzeppelin/test-helpers');
const { BigNumber } = ethers;
const parseEther = ethers.utils.parseEther;
const { increaseTime, etherBalance } = require("../../scripts/utils/ethereum");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable.json").abi;

const { common, ethMainnet: network_ } = require("../../parameters");

const DAY = 24 * 3600;

function getUsdVaule(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}
function getUsdtAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}
function getBnbAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(18))
}
function e(decimals) {
  return BigNumber.from(10).pow(decimals)
}

describe("STI on ETH", async () => {

    let vault, strategy, stVault, priceOracle, usdt, nft;
    let stMaticVault, stMaticNft;
    let vaultArtifact, strategyArtifact, stVaultArtifact, priceOracleArtifact, nftArtifact;
    let admin;

    before(async () => {
      [deployer, a1, a2, ...accounts] = await ethers.getSigners();
  
      vaultArtifact = await deployments.getArtifact("STIVault");
      strategyArtifact = await deployments.getArtifact("EthSTIStrategy");
      stVaultArtifact = await deployments.getArtifact("EthStETHVault");
      nftArtifact = await deployments.getArtifact("StVaultNFT");
      priceOracleArtifact = await deployments.getArtifact("EthPriceOracle");
    });

    beforeEach(async () => {
      await deployments.fixture(["hardhat_eth_sti"])

      const vaultProxy = await ethers.getContract("STIVault_Proxy");
      vault = new ethers.Contract(vaultProxy.address, vaultArtifact.abi, a1);
      const strategyProxy = await ethers.getContract("EthSTIStrategy_Proxy");
      strategy = new ethers.Contract(strategyProxy.address, strategyArtifact.abi, a1);
      stVault = new ethers.Contract(await strategy.ETHVault(), stVaultArtifact.abi, a1);
      nft = new ethers.Contract(await stVault.nft(), nftArtifact.abi, a1);
      stMaticVault = new ethers.Contract(await strategy.MATICVault(), stVaultArtifact.abi, a1);
      stMaticNft = new ethers.Contract(await stMaticVault.nft(), nftArtifact.abi, a1);
      const priceOracleProxy = await ethers.getContract("EthPriceOracle_Proxy");
      priceOracle = new ethers.Contract(priceOracleProxy.address, priceOracleArtifact.abi, a1);

      admin = await ethers.getSigner(common.admin);

      usdt = new ethers.Contract(network_.Token.USDT, ERC20_ABI, deployer);
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
        expect(await vault.USDT()).equal(network_.Token.USDT);

        expect(await strategy.owner()).equal(deployer.address);
        expect(await strategy.admin()).equal(common.admin);
        expect(await strategy.vault()).equal(vault.address);
        expect(await strategy.priceOracle()).equal(priceOracle.address);
        expect(await strategy.router()).equal('0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D');
        expect(await strategy.SWAP_BASE_TOKEN()).equal(network_.Token.WETH);
        expect(await strategy.USDT()).equal(network_.Token.USDT);
        expect(await strategy.tokens(0)).equal(common.nativeAsset);
        expect(await strategy.tokens(1)).equal(network_.Token.MATIC);
        expect(await strategy.pid(common.nativeAsset)).equal(0);
        expect(await strategy.pid(network_.Token.MATIC)).equal(1);

        expect(await stVault.name()).equal('STI Staking ETH');
        expect(await stVault.symbol()).equal('stiStETH');
        expect(await stVault.treasuryWallet()).equal(common.treasury);
        expect(await stVault.admin()).equal(common.admin);
        expect(await stVault.priceOracle()).equal(priceOracle.address);
        expect(await stVault.yieldFee()).equal(2000);
        expect(await stVault.nft()).equal(await nftFactory.getNFTByVault(stVault.address));
        expect(await stVault.token()).equal(common.nativeAsset);
        expect(await stVault.stToken()).equal(network_.Token.stETH);

        expect(await stMaticVault.name()).equal('STI Staking MATIC');
        expect(await stMaticVault.symbol()).equal('stiStMATIC');
        expect(await stMaticVault.treasuryWallet()).equal(common.treasury);
        expect(await stMaticVault.admin()).equal(common.admin);
        expect(await stMaticVault.priceOracle()).equal(priceOracle.address);
        expect(await stMaticVault.yieldFee()).equal(2000);
        expect(await stMaticVault.nft()).equal(await nftFactory.getNFTByVault(stMaticVault.address));
        expect(await stMaticVault.token()).equal(network_.Token.MATIC);
        expect(await stMaticVault.stToken()).equal(network_.Token.stMATIC);
      });

      it("Should be set by only owner", async () => {
        await expectRevert(priceOracle.setAssetSources([a2.address],[a1.address]), "Ownable: caller is not the owner");

        await expectRevert(vault.setAdmin(a2.address), "Ownable: caller is not the owner");
        await expectRevert(vault.depositByAdmin(a1.address, [a2.address], [getUsdVaule('100')]), "Only owner or admin");
        await expectRevert(vault.withdrawPercByAdmin(a1.address, parseEther('0.1')), "Only owner or admin");
        await expectRevert(vault.emergencyWithdraw(), "Only owner or admin");
        await expectRevert(vault.claimEmergencyWithdrawal(), "Only owner or admin");
        await expectRevert(vault.reinvest([a2.address], [10000]), "Only owner or admin");
        await expectRevert(vault.setStrategy(a2.address), "Ownable: caller is not the owner");

        await expectRevert(strategy.addToken(a1.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.removeToken(1), "Ownable: caller is not the owner");
        await expectRevert(strategy.setAdmin(a2.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.setVault(a2.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.setStVault(a1.address, a2.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.invest([a2.address], [getUsdVaule('100')]), "Only vault");
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

        await expectRevert(stMaticVault.setAdmin(a2.address), "Ownable: caller is not the owner");
        await stMaticVault.connect(deployer).setAdmin(a2.address);
        expect(await stMaticVault.admin()).equal(a2.address);
        await stMaticVault.connect(deployer).setAdmin(accounts[0].address);

        await expectRevert(stMaticVault.setTreasuryWallet(a2.address), "Ownable: caller is not the owner");
        await stMaticVault.connect(deployer).setTreasuryWallet(a2.address);
        expect(await stMaticVault.treasuryWallet()).equal(a2.address);
        await stMaticVault.connect(deployer).setTreasuryWallet(common.treasury);

        await expectRevert(stMaticVault.setFee(1000), "Ownable: caller is not the owner");
        await stMaticVault.connect(deployer).setFee(1000);
        expect(await stMaticVault.yieldFee()).equal(1000);

        await expectRevert(stMaticVault.setNFT(a2.address), "Ownable: caller is not the owner");
        await expectRevert(stMaticVault.connect(deployer).setNFT(a2.address), "Already set");

        await expectRevert(stMaticVault.setStakingPeriods(1,2,3,4), "Ownable: caller is not the owner");
        await stMaticVault.connect(deployer).setStakingPeriods(1,2,3,4);
        expect(await stMaticVault.unbondingPeriod()).equal(1);
        expect(await stMaticVault.investInterval()).equal(2);
        expect(await stMaticVault.redeemInterval()).equal(3);
        expect(await stMaticVault.oneEpoch()).equal(4);

        await expectRevert(stMaticVault.setStakingAmounts(5,6), "Ownable: caller is not the owner");
        await stMaticVault.connect(deployer).setStakingAmounts(5,6);
        expect(await stMaticVault.minInvestAmount()).equal(5);
        expect(await stMaticVault.minRedeemAmount()).equal(6);
        await stMaticVault.connect(deployer).setStakingAmounts(1,1);

        await expectRevert(stMaticVault.resetApr(), "Ownable: caller is not the owner");
        await stMaticVault.connect(deployer).resetApr();

        await expectRevert(stMaticVault.invest(), "Only owner or admin");
        await stMaticVault.connect(accounts[0]).invest();
        
        await expectRevert(stMaticVault.redeem(), "Only owner or admin");
        await expectRevert(stMaticVault.connect(accounts[0]).redeem(), "too small");

        await expectRevert(stMaticVault.claimUnbonded(), "Only owner or admin");
        await stMaticVault.connect(accounts[0]).claimUnbonded();

        await expectRevert(stMaticVault.emergencyWithdraw(), "Only owner or admin");
        await stMaticVault.connect(accounts[0]).emergencyWithdraw();
        await expectRevert(stMaticVault.connect(deployer).emergencyWithdraw(), "Pausable: paused");

        await expectRevert(stMaticVault.emergencyRedeem(), "Only owner or admin");
        await stMaticVault.connect(accounts[0]).emergencyRedeem();

        await expectRevert(stMaticVault.reinvest(), "Only owner or admin");
        await stMaticVault.connect(accounts[0]).reinvest();
        await expectRevert(stMaticVault.connect(deployer).reinvest(), "Pausable: not paused");

        await expectRevert(stMaticVault.yield(), "Only owner or admin");
        await stMaticVault.connect(accounts[0]).yield();

        await expectRevert(stMaticVault.collectProfitAndUpdateWatermark(), "Only owner or admin");
        await stMaticVault.connect(accounts[0]).collectProfitAndUpdateWatermark();

        await expectRevert(stMaticVault.withdrawFees(), "Only owner or admin");
        await stMaticVault.connect(accounts[0]).withdrawFees();
      });

      it("Should be returned with correct default vaule", async () => {
        expect(await vault.getAPR()).equal(0); // Because there is no L2 vault
        expect(await vault.getAllPoolInUSD()).equal(0);

        var ret = await vault.getEachPoolInUSD();
        chainIDs = ret[0];
        tokens = ret[1];
        pools = ret[2];
        expect(chainIDs.length).equal(2);
        // expect(chainIDs[0]).equal(1313161554);
        expect(tokens[0]).equal(common.nativeAsset);
        expect(tokens[1]).equal(network_.Token.MATIC);
        expect(pools[0]).equal(0);
        expect(pools[1]).equal(0);
      });
    });

    // describe('Basic function', () => {
    //   beforeEach(async () => {
    //     vault.connect(deployer).setAdmin(accounts[0].address);
    //     stVault.connect(deployer).setAdmin(accounts[0].address);
    //     admin = accounts[0];
    //   });

    //   it("Basic Deposit/withdraw with small amount", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('50000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

    //     const aBNBb = new ethers.Contract(network_.Token.aBNBb, ERC20_ABI, deployer);

    //     // deposit
    //     var ret = await vault.getEachPoolInUSD();
    //     var tokens = ret[1];
    //     await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdVaule('50000')]);

    //     expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(100));

    //     expect(await usdt.balanceOf(a1.address)).equal(0);
    //     expect(await usdt.balanceOf(vault.address)).equal(0);
    //     expect(await usdt.balanceOf(strategy.address)).equal(0);

    //     ret = await priceOracle.getAssetPrice(common.nativeAsset);
    //     const BNBPrice = ret[0];
    //     const BNBPriceDecimals = ret[1];
    //     const BNBAmt = getBnbAmount(1).mul(50000).div(BNBPrice).mul(e(BNBPriceDecimals));

    //     const BNBDeposits = await etherBalance(stVault.address);
    //     expect(await etherBalance(strategy.address)).equal(0);
    //     expect(BNBDeposits).closeTo(BNBAmt, BNBAmt.div(100));

    //     expect(await stVault.bufferedDeposits()).equal(BNBDeposits);
    //     expect(await stVault.totalSupply()).equal(BNBDeposits);

    //     // invest
    //     await stVault.connect(admin).invest();

    //     expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(50));
    //     expect(await etherBalance(stVault.address)).lt(e(10));

    //     const aBNBbAmt = await stVault.getStTokenByPooledToken(BNBDeposits);
    //     const aBNBbBalance = await aBNBb.balanceOf(stVault.address);
    //     expect(aBNBbBalance).closeTo(aBNBbAmt, aBNBbAmt.div(50));
    //     expect(await stVault.getInvestedStTokens()).equal(0);
    //     expect(await stVault.bufferedDeposits()).lt(e(10));
    //     expect(await stVault.totalSupply()).equal(BNBDeposits);

    //     // withdraw all
    //     await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1'));
    //     let usdtBalance = await usdt.balanceOf(a1.address);
    //     expect(usdtBalance).gte(0);
    //     expect(await stVault.bufferedDeposits()).equal(0);
    //     expect(await nft.totalSupply()).equal(1);
    //     expect(await nft.exists(1)).equal(true);
    //     expect(await nft.isApprovedOrOwner(strategy.address, 1)).equal(true);
    //     expect(await stVault.pendingRedeems()).closeTo(aBNBbBalance, aBNBbBalance.div(100));
    //     expect(await stVault.pendingWithdrawals()).closeTo(BNBDeposits, BNBDeposits.div(50));
    //     expect(await vault.getAllPoolInUSD()).equal(0);
    //     ret = await vault.getUnbondedAll(a1.address);
    //     let waitingInUSD = ret[0];
    //     let unbondedInUSD = ret[1];
    //     let waitForTs = ret[2];
    //     expect(waitingInUSD).gt(0);
    //     expect(unbondedInUSD).equal(0);
    //     const unbondingPeriod = await stVault.unbondingPeriod();
    //     expect(waitForTs).closeTo(unbondingPeriod, unbondingPeriod.div(100));
    //     expect(usdtBalance.add(waitingInUSD)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(25));

    //     ret = await vault.getUnbondedAll(a2.address);
    //     expect(ret[0]).equal(0);
    //     expect(ret[1]).equal(0);
    //     expect(ret[2]).equal(0);

    //     var ret = await vault.getPoolsUnbonded(a1.address);
    //     chainIDs = ret[0];
    //     tokens = ret[1];
    //     waitings = ret[2];
    //     waitingInUSDs = ret[3];
    //     unbondeds = ret[4];
    //     unbondedInUSDs = ret[5];
    //     waitForTses = ret[6];
    //     expect(chainIDs.length).equal(1);
    //     expect(tokens[0]).equal(common.nativeAsset);
    //     expect(waitings[0]).gt(0);
    //     expect(waitingInUSDs[0]).gt(0);
    //     expect(unbondeds[0]).equal(0);
    //     expect(unbondedInUSDs[0]).equal(0);
    //     expect(waitForTses[0]).closeTo(unbondingPeriod, unbondingPeriod.div(100));

    //     var ret = await vault.getUnbondedAll(a1.address);
    //     expect(waitingInUSDs[0]).equal(ret[0]);
    //     expect(unbondedInUSDs[0]).equal(ret[1]);
    //     expect(waitForTses[0]).equal(ret[2]);

    //     // redeem on stVault
    //     await stVault.connect(admin).redeem();
    //     expect(await stVault.pendingRedeems()).equal(0);
    //     expect(await stVault.pendingWithdrawals()).closeTo(BNBDeposits, BNBDeposits.div(50));
    //     expect(await aBNBb.balanceOf(stVault.address)).closeTo(BigNumber.from(10), 10);

    //     // try before the end of unbonding. it should be failed.
    //     await increaseTime(waitForTs-10);
    //     await vault.connect(admin).claimByAdmin(a1.address);
    //     expect(await usdt.balanceOf(a1.address)).equal(usdtBalance); // no claimed
    //     await vault.connect(a1).claim();
    //     expect(await usdt.balanceOf(a1.address)).equal(usdtBalance); // no claimed

    //     await increaseTime(10);
    //     await vault.connect(a2).claim();
    //     expect(await usdt.balanceOf(a2.address)).equal(0); // no claimed

    //     // Even though the unbundoing period is over, it's not claimable if no token claimed in stVault
    //     ret = await vault.getUnbondedAll(a1.address);
    //     expect(ret[0]).gt(0);
    //     expect(ret[1]).equal(0);
    //     expect(ret[2]).equal(0);

    //     // claim the unbonded on stVault;
    //     expect(await stVault.getUnbondedToken()).equal(0);

    //     // await vault.connect(a1).claim();
    //     // expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(25));

    //     // ret = await vault.getUnbondedAll(a1.address);
    //     // expect(ret[0]).equal(0);
    //     // expect(ret[1]).equal(0);
    //     // expect(ret[2]).equal(0);
    //     // expect(await nft.totalSupply()).equal(0);

    //     // expect(await stVault.totalSupply()).equal(0);
    //     // expect(await usdt.balanceOf(vault.address)).equal(0);
    //     // expect(await usdt.balanceOf(strategy.address)).equal(0);
    //     // expect(await etherBalance(strategy.address)).equal(0);
    //     // expect(await etherBalance(stVault.address)).equal(0);
    //     // expect(await aBNBb.balanceOf(stVault.address)).equal(0);
    //   });

    //   it("emergencyWithdraw", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('50000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));
    //     await usdt.transfer(a2.address, getUsdtAmount('50000'));
    //     await usdt.connect(a2).approve(vault.address, getUsdtAmount('50000'));

    //     const aBNBb = new ethers.Contract(network_.Token.aBNBb, ERC20_ABI, deployer);

    //     // deposit
    //     var ret = await vault.getEachPoolInUSD();
    //     var tokens = ret[1];
    //     await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdVaule('50000')]);
    //     await stVault.connect(admin).invest();
    //     await vault.connect(admin).depositByAdmin(a2.address, tokens, [getUsdVaule('50000')]);

    //     expect(await vault.getAllPoolInUSD()).closeTo(parseEther('100000'), parseEther('100000').div(100));

    //     ret = await priceOracle.getAssetPrice(common.nativeAsset);
    //     const BNBPrice = ret[0];
    //     const BNBPriceDecimals = ret[1];
    //     const BNBAmt = getBnbAmount(1).mul(50000).div(BNBPrice).mul(e(BNBPriceDecimals));

    //     const BNBDeposits = await etherBalance(stVault.address);
    //     expect(await etherBalance(strategy.address)).equal(0);
    //     expect(BNBDeposits).closeTo(BNBAmt, BNBAmt.div(100));

    //     expect(await stVault.bufferedDeposits()).equal(BNBDeposits);
    //     expect(await stVault.totalSupply()).closeTo(BNBDeposits.mul(2), BNBDeposits.mul(2).div(50));

    //     const aBNBbAmt = await stVault.getStTokenByPooledToken(BNBDeposits);
    //     const aBNBbBalance = await aBNBb.balanceOf(stVault.address);
    //     expect(aBNBbBalance).closeTo(aBNBbAmt, aBNBbAmt.div(50));

    //     // emergencyWithdraw before investment
    //     await vault.connect(admin).emergencyWithdraw();

    //     expect(await vault.getAllPoolInUSD()).closeTo(parseEther('100000'), parseEther('100000').div(50));
    //     expect(await stVault.totalSupply()).equal(0);

    //     // check if deposit is disabled
    //     await usdt.transfer(a2.address, getUsdtAmount('10000'));
    //     await usdt.connect(a2).approve(vault.address, getUsdtAmount('10000'));
    //     await expectRevert(vault.connect(admin).depositByAdmin(a2.address, tokens, [getUsdVaule('10000')]), "Pausable: paused");

    //     await expectRevert(vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').div(2)), "Retry after all claimed");

    //     // // withdraw all of a1's deposit
    //     // await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').div(2));
    //     // let usdtBalance = await usdt.balanceOf(a1.address);
    //     // expect(usdtBalance).gte(0);
    //     // expect(await stVault.bufferedDeposits()).equal(0);
    //     // expect(await nft.totalSupply()).equal(1);
    //     // expect(await nft.exists(1)).equal(true);
    //     // expect(await nft.isApprovedOrOwner(strategy.address, 1)).equal(true);
    //     // expect(await stVault.pendingRedeems()).closeTo(aBNBbBalance, aBNBbBalance.div(100));
    //     // expect(await stVault.pendingWithdrawals()).closeTo(BNBDeposits, BNBDeposits.div(50));
    //     // expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(50));
    //     // ret = await vault.getUnbondedAll(a1.address);
    //     // let waitingInUSD = ret[0];
    //     // let unbondedInUSD = ret[1];
    //     // let waitForTs = ret[2];
    //     // expect(waitingInUSD).equal(0);
    //     // expect(unbondedInUSD).equal(0);
    //     // expect(waitForTs).equal(0);
    //     // expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(20));

    //     // // reinvest
    //     // ret = await vault.getCurrentCompositionPerc();
    //     // await vault.connect(admin).reinvest(ret[0], ret[1]);

    //     // expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(20));
    //     // expect(await usdt.balanceOf(vault.address)).equal(0);
    //     // expect(await etherBalance(stVault.address)).closeTo(BNBDeposits, BNBDeposits.div(20));
    //     // expect(await stVault.bufferedDeposits()).equal(await etherBalance(stVault.address));
    //     // expect(await stVault.totalSupply()).closeTo(BNBDeposits, BNBDeposits.div(20));

    //     // await increaseTime(5*60);
    //     // await stVault.connect(admin).invest();
    //     // expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(20));
    //     // expect(await etherBalance(stVault.address)).equal(0);
    //     // expect(await aBNBb.balanceOf(stVault.address)).closeTo(aBNBbBalance, aBNBbBalance.div(100));
    //   });
    // });

    // describe('StVault', () => {
    //   beforeEach(async () => {
    //     vault.connect(deployer).setAdmin(accounts[0].address);
    //     stVault.connect(deployer).setAdmin(accounts[0].address);
    //     admin = accounts[0];
    //   });

    //   it("emergencyWithdraw", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('50000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

    //     const aBNBb = new ethers.Contract(network_.Token.aBNBb, ERC20_ABI, deployer);

    //     // deposit & invest
    //     var ret = await vault.getEachPoolInUSD();
    //     var tokens = ret[1];
    //     await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdVaule('50000')]);
    //     const BNBDeposits = await etherBalance(stVault.address);

    //     await stVault.connect(admin).invest();

    //     expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(50));
    //     expect(await etherBalance(stVault.address)).lt(e(10));
    //     const aBNBbBalance = await aBNBb.balanceOf(stVault.address);

    //     // emergency on stVault
    //     await stVault.connect(admin).emergencyWithdraw();

    //     expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(50));
    //     expect(await etherBalance(stVault.address)).gt(0);
    //     expect(await aBNBb.balanceOf(stVault.address)).closeTo(BigNumber.from(1), 1);
    //     expect(await stVault.pendingWithdrawals()).equal(0);
    //     expect(await stVault.totalSupply()).equal(BNBDeposits);
    //     expect(await stVault.getEmergencyUnbondings()).equal(aBNBbBalance);

    //     // withdraw 20000 USD
    //     await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(2).div(5));
    //     let usdtBalance = await usdt.balanceOf(a1.address);
    //     expect(usdtBalance).gte(0);
    //     expect(await nft.totalSupply()).equal(1);
    //     expect(await nft.exists(1)).equal(true);
    //     expect(await nft.isApprovedOrOwner(strategy.address, 1)).equal(true);
    //     expect(await stVault.pendingRedeems()).equal(0);
    //     expect(await stVault.pendingWithdrawals()).closeTo(BNBDeposits.mul(2).div(5), BNBDeposits.mul(2).div(5).div(50));
    //     expect(await stVault.totalSupply()).closeTo(BNBDeposits.mul(3).div(5), BNBDeposits.mul(3).div(5).div(50));
    //     expect(await stVault.getEmergencyUnbondings()).closeTo(aBNBbBalance.mul(3).div(5), aBNBbBalance.mul(3).div(5).div(50));
    //     expect(await vault.getAllPoolInUSD()).closeTo(parseEther('30000'), parseEther('30000').div(50));
    //     ret = await vault.getUnbondedAll(a1.address);
    //     let waitingInUSD = ret[0];
    //     let unbondedInUSD = ret[1];
    //     let waitForTs = ret[2];
    //     expect(waitingInUSD).closeTo(parseEther('20000'), parseEther('20000').div(50));
    //     expect(unbondedInUSD).equal(0);
    //     expect(waitForTs).gt(0);
    //     expect(usdtBalance.add(waitingInUSD)).closeTo(getUsdtAmount('20000'), getUsdtAmount('20000').div(50));

    //     // withdraw again 20000 USD
    //     await increaseTime(DAY);
    //     await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(2).div(3));
    //     expect(await nft.totalSupply()).equal(2);
    //     expect(await nft.exists(2)).equal(true);
    //     expect(await nft.isApprovedOrOwner(strategy.address, 2)).equal(true);
    //     expect(await stVault.pendingRedeems()).equal(0);
    //     expect(await stVault.pendingWithdrawals()).closeTo(BNBDeposits.mul(4).div(5), BNBDeposits.mul(4).div(5).div(50));
    //     expect(await stVault.totalSupply()).closeTo(BNBDeposits.div(5), BNBDeposits.div(5).div(50));
    //     expect(await stVault.getEmergencyUnbondings()).closeTo(aBNBbBalance.div(5), aBNBbBalance.div(5).div(50));
    //     expect(await vault.getAllPoolInUSD()).closeTo(parseEther('10000'), parseEther('10000').div(50));
    //     ret = await vault.getUnbondedAll(a1.address);
    //     waitingInUSD = ret[0];
    //     unbondedInUSD = ret[1];
    //     expect(waitingInUSD).closeTo(parseEther('40000'), parseEther('40000').div(50));
    //     expect(unbondedInUSD).equal(0);
    //     expect(ret[2]).lt(waitForTs);
    //     expect(usdtBalance.add(waitingInUSD)).closeTo(getUsdtAmount('40000'), getUsdtAmount('40000').div(50));

    //     await expectRevert(stVault.connect(admin).reinvest(), "Emergency unbonding is not finished");

    //     // // reinvest on stVault
    //     // await stVault.connect(admin).reinvest();

    //     // // withdraw all
    //     // await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1'));
    //     // usdtBalance = await usdt.balanceOf(a1.address);
    //     // expect(usdtBalance).gt(0); // Some aBNBbs is not swapped to WNEAR because metaPool buffer is insufficient
    //     // // expect(await nft.totalSupply()).equal(1);
    //     // // expect(await nft.exists(1)).equal(true);
    //     // // expect(await nft.isApprovedOrOwner(strategy.address, 1)).equal(true);
    //     // // expect(await stVault.pendingRedeems()).gt(0);
    //     // expect(await vault.getAllPoolInUSD()).equal(0);
    //     // ret = await vault.getUnbondedAll(a1.address);
    //     // waitingInUSD = ret[0];
    //     // unbondedInUSD = ret[1];
    //     // waitForTs = ret[2];
    //     // expect(waitingInUSD).equal(0);
    //     // expect(unbondedInUSD).equal(0);
    //     // expect(waitForTs).equal(0);
    //     // expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(50));

    //     // expect(await stVault.totalSupply()).equal(0);
    //     // expect(await usdt.balanceOf(vault.address)).equal(0);
    //     // expect(await usdt.balanceOf(strategy.address)).equal(0);
    //     // expect(await etherBalance(strategy.address)).equal(0);
    //     // expect(await etherBalance(stVault.address)).equal(0);
    //     // expect(await aBNBb.balanceOf(stVault.address)).closeTo(aBNBbVaultShare.div(50000), aBNBbVaultShare.div(50000));
    //   });
    // });

});