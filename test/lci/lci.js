const { expect } = require("chai");
const { assert, ethers, deployments } = require("hardhat");
const { expectRevert } = require('@openzeppelin/test-helpers');
const { BigNumber } = ethers;
const parseEther = ethers.utils.parseEther;
const { increaseTime } = require("../../scripts/utils/ethereum");

const ERC20_ABI = require("../../node_modules/@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable.json").abi;
const CHAINLINK_ABI = [
  {"inputs":[],"name":"latestAnswer","outputs":[{"internalType":"int256","name":"","type":"int256"}],"stateMutability":"view","type":"function"}
];

const { common, bscMainnet: network_ } = require("../../parameters");

const DAY = 24 * 3600;

const DENOMINATOR = 10000;

function e(pow) {
  return BigNumber.from(10).pow(pow);
}

describe("LCI", async () => {

    let vault, strategy, usdt;
    let vaultArtifact, strategyArtifact;
    let admin;
    let cakeFeed;

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

      cakeFeed = new ethers.Contract('0xB6064eD41d4f67e353768aA239cA86f4F73665a1', CHAINLINK_ABI, deployer);
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

        expect(await strategy.vault()).equal(vault.address);
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

      // it("Should be set by only owner", async () => {
      //   await expectRevert(fw.invest(), "Only owner or admin");
      //   await fw.connect(admin).invest();

      //   await expectRevert(fw.emergencyWithdraw(), "Only owner or admin");
      //   await fw.connect(admin).emergencyWithdraw();
      //   await expectRevert(fw.connect(deployer).emergencyWithdraw(), "Pausable: paused");

      //   await expectRevert(fw.reinvest(), "Only owner or admin");
      //   await fw.connect(admin).reinvest();
      //   await expectRevert(fw.connect(deployer).reinvest(), "Pausable: not paused");

      //   await expectRevert(fw.yield(), "Only owner or admin");
      //   await fw.connect(admin).yield();
      //   await fw.connect(admin).emergencyWithdraw();
      //   await expectRevert(fw.connect(deployer).yield(), "Pausable: paused");
      //   await fw.connect(admin).reinvest();

      //   await expectRevert(fw.setMarketState(BULLISH), "Only owner or admin");
      //   await fw.connect(admin).setMarketState(BULLISH);
      //   expect(await fw.marketState()).equal(BULLISH);
      //   await fw.connect(admin).emergencyWithdraw();
      //   await expectRevert(fw.connect(deployer).setMarketState(BEARISH), "Pausable: paused");
      //   await fw.connect(admin).reinvest();
      //   await fw.connect(admin).setMarketState(BEARISH);

      //   await expectRevert(fw.setAdmin(a2.address), "Ownable: caller is not the owner");
      //   await fw.connect(deployer).setAdmin(a2.address);
      //   expect(await fw.admin()).equal(a2.address);
      //   await fw.connect(deployer).setAdmin(admin.address);

      //   await expectRevert(fw.setBiconomy(a2.address), "Ownable: caller is not the owner");
      //   await fw.connect(deployer).setBiconomy(a2.address);
      //   expect(await fw.trustedForwarder()).equal(a2.address);
      //   await fw.connect(deployer).setBiconomy(network_.biconomy);

      //   await expectRevert(fw.setNetworkFeeTier3([1,2,3]), "Ownable: caller is not the owner");
      //   await fw.connect(deployer).setNetworkFeeTier3([1,2,3]);
      //   expect(await fw.networkFeeTier3(0)).equal(1);
      //   expect(await fw.networkFeeTier3(1)).equal(2);
      //   expect(await fw.networkFeeTier3(2)).equal(3);

      //   await expectRevert(fw.setNetworkFeePerc([0,1,2,3]), "Ownable: caller is not the owner");
      //   await fw.connect(deployer).setNetworkFeePerc([0,1,2,3]);
      //   expect(await fw.networkFeePerc(0)).equal(0);
      //   expect(await fw.networkFeePerc(1)).equal(1);
      //   expect(await fw.networkFeePerc(2)).equal(2);
      //   expect(await fw.networkFeePerc(3)).equal(3);

      //   await expectRevert(fw.setYieldFeePerc(1000), "Ownable: caller is not the owner");
      //   await fw.connect(deployer).setYieldFeePerc(1000);
      //   expect(await fw.yieldFeePerc()).equal(1000);

      //   await expectRevert(fw.setTreasuryWallet(a2.address), "Ownable: caller is not the owner");
      //   await fw.connect(deployer).setTreasuryWallet(a2.address);
      //   expect(await fw.treasuryWallet()).equal(a2.address);
      //   await fw.connect(deployer).setTreasuryWallet(network_.treasury);

      //   await expectRevert(fw.setSubImpl(a2.address), "Ownable: caller is not the owner");
      //   await fw.connect(deployer).setSubImpl(a2.address);
      //   expect(await fw.subImpl()).equal(a2.address);
      //   const subImpl = await deployments.get("FoloWhaleSub");
      //   await fw.connect(deployer).setSubImpl(subImpl.address);
      // });
    });

    // describe('Test with USDT', () => {
    //   it("Deposit/withdraw", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('50000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('50000'));

    //     await expectRevert(fw.deposit(getUsdtAmount('50000'), '0xd91Fbc9b431464D737E1BC4e76900D43405a639b'), "Invalid token deposit");
    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     const fee = parseEther('50000').mul(100).div(PERC_DENOMINATOR)
    //     expect(await fw.depositAmt(a1.address)).equal(parseEther('50000').sub(fee));
    //     expect(await fw.totalDepositAmt()).equal(parseEther('50000').sub(fee));
    //     expect(await fw.fees()).equal(fee);
    //     expect(await fw.getTotalPendingDeposits()).equal(1);
    //     expect(await fw.totalSupply()).equal(0);
    //     expect(await fw.getAllPoolInUSD()).equal(parseEther('50000').sub(fee));
    //     expect(await fw.getPricePerFullShare()).equal(parseEther('1'));

    //     const treasuryBalanceBefore = await usdt.balanceOf(network_.treasury);
    //     await fw.connect(admin).invest();
    //     expect((await usdt.balanceOf(network_.treasury)).sub(treasuryBalanceBefore)).equal(getUsdtAmount('50000').mul(100).div(PERC_DENOMINATOR));
    //     expect(await fw.depositAmt(a1.address)).equal(0);
    //     expect(await fw.totalDepositAmt()).equal(0);
    //     expect(await fw.fees()).equal(0);
    //     expect(await fw.getTotalPendingDeposits()).equal(0);
    //     expect(await fw.totalSupply()).equal(parseEther('50000').sub(fee));
    //     expect(await fw.balanceOf(a1.address)).equal(parseEther('50000').sub(fee));

    //     await increaseTime(DAY);
    //     expect(await fw.getPendingRewards()).gt(0);

    //     await fw.connect(admin).yield();
    //     expect(await fw.getAllPoolInUSD()).gte(parseEther('50000').sub(fee));
    //     expect(await fw.getPricePerFullShare()).gte(parseEther('1'));
    //     const apr = await fw.getAPR();
    //     expect(apr).gt(0);

    //     await increaseTime(DAY);
    //     expect(await fw.getAPR()).gt(apr);

    //     await fw.withdraw(await fw.balanceOf(a1.address), usdt.address);
    //     expect(await fw.totalSupply()).equal(0);
    //     expect(await fw.balanceOf(a1.address)).equal(0);
    //     expect(await fw.getAllPoolInUSD()).gte(0);
    //     expect(await fw.getPricePerFullShare()).gte(parseEther('1'));
    //     expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000').mul(99).div(100), getUsdtAmount('50000').div(100));
    //   });

    //   it("Test Deposit fee", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('5000000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('5000000'));

    //     await fw.deposit(getUsdtAmount('100000'), usdt.address);
    //     var fee = parseEther('100000').mul(75).div(PERC_DENOMINATOR)
    //     expect(await fw.depositAmt(a1.address)).equal(parseEther('100000').sub(fee));
    //     expect(await fw.totalDepositAmt()).equal(parseEther('100000').sub(fee));
    //     expect(await fw.fees()).equal(fee);
    //     await fw.connect(admin).invest();
    //     await fw.withdraw(await fw.balanceOf(a1.address), usdt.address);

    //     await fw.deposit(getUsdtAmount('1000000'), usdt.address);
    //     var fee = parseEther('1000000').mul(50).div(PERC_DENOMINATOR)
    //     expect(await fw.depositAmt(a1.address)).equal(parseEther('1000000').sub(fee));
    //     expect(await fw.totalDepositAmt()).equal(parseEther('1000000').sub(fee));
    //     expect(await fw.fees()).equal(fee);
    //     await fw.connect(admin).invest();
    //     await fw.withdraw(await fw.balanceOf(a1.address), usdt.address);

    //     await fw.deposit(getUsdtAmount('1000001'), usdt.address);
    //     var fee = parseEther('1000001').mul(25).div(PERC_DENOMINATOR)
    //     expect(await fw.depositAmt(a1.address)).equal(parseEther('1000001').sub(fee));
    //     expect(await fw.totalDepositAmt()).equal(parseEther('1000001').sub(fee));
    //     expect(await fw.fees()).equal(fee);
    //     await fw.connect(admin).invest();
    //     await fw.withdraw(await fw.balanceOf(a1.address), usdt.address);
    //   });

    //   it("Deposit again before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('100000'));

    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     const fee = parseEther('50000').mul(100).div(PERC_DENOMINATOR)
    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     expect(await fw.depositAmt(a1.address)).equal(parseEther('50000').sub(fee).mul(2));
    //     expect(await fw.totalDepositAmt()).equal(parseEther('50000').sub(fee).mul(2));
    //     expect(await fw.fees()).equal(fee.mul(2));
    //     expect(await fw.getTotalPendingDeposits()).equal(1);
    //     expect(await fw.totalSupply()).equal(0);
    //     expect(await fw.getAllPoolInUSD()).equal(parseEther('50000').sub(fee).mul(2));
    //     expect(await fw.getPricePerFullShare()).equal(parseEther('1'));

    //     const treasuryBalanceBefore = await usdt.balanceOf(network_.treasury);
    //     await fw.connect(admin).invest();
    //     expect((await usdt.balanceOf(network_.treasury)).sub(treasuryBalanceBefore)).equal(getUsdtAmount('100000').mul(100).div(PERC_DENOMINATOR));
    //     expect(await fw.depositAmt(a1.address)).equal(0);
    //     expect(await fw.totalDepositAmt()).equal(0);
    //     expect(await fw.fees()).equal(0);
    //     expect(await fw.getTotalPendingDeposits()).equal(0);
    //     expect(await fw.totalSupply()).equal(parseEther('50000').sub(fee).mul(2));
    //     expect(await fw.getAllPoolInUSD()).closeTo(parseEther('50000').sub(fee).mul(2), parseEther('50000').sub(fee).mul(2).div(100));
    //     expect(await fw.balanceOf(a1.address)).equal(parseEther('50000').sub(fee).mul(2));
    //   });

    //   it("Deposit again after invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('100000'));

    //     const treasuryBalanceBefore = await usdt.balanceOf(network_.treasury);
    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     const fee = parseEther('50000').mul(100).div(PERC_DENOMINATOR)
    //     await fw.connect(admin).invest();

    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.connect(admin).invest();
    //     expect((await usdt.balanceOf(network_.treasury)).sub(treasuryBalanceBefore)).equal(getUsdtAmount('100000').mul(100).div(PERC_DENOMINATOR));
    //     expect(await fw.depositAmt(a1.address)).equal(0);
    //     expect(await fw.totalDepositAmt()).equal(0);
    //     expect(await fw.fees()).equal(0);
    //     expect(await fw.getTotalPendingDeposits()).equal(0);
    //     expect(await fw.totalSupply()).closeTo(parseEther('50000').sub(fee).mul(2), parseEther('50000').sub(fee).mul(2).div(100));
    //     expect(await fw.getAllPoolInUSD()).closeTo(parseEther('50000').sub(fee).mul(2), parseEther('50000').sub(fee).mul(2).div(100));
    //     expect(await fw.balanceOf(a1.address)).closeTo(parseEther('50000').sub(fee).mul(2), parseEther('50000').sub(fee).mul(2).div(100));
    //   });

    //   it("Test emergencyWithdraw", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('50000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('50000'));

    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     const fee = parseEther('50000').mul(100).div(PERC_DENOMINATOR)

    //     await fw.connect(admin).emergencyWithdraw();
    //     expect(await fw.getAllPoolInUSD()).equal(parseEther('50000').sub(fee));
    //     await fw.connect(admin).reinvest();
    //     expect(await fw.getAllPoolInUSD()).closeTo(parseEther('50000').sub(fee), parseEther('50000').sub(fee).div(1000));
    //     await fw.connect(admin).emergencyWithdraw();
    //     expect(await fw.getAllPoolInUSD()).closeTo(parseEther('50000').sub(fee), parseEther('50000').sub(fee).div(1000));

    //     expect(await fw.getPricePerFullShare()).closeTo(parseEther('1'), parseEther('1').div(1000));
    //     expect(await fw.getAPR()).equal(0);
    //     expect(await fw.getPendingRewards()).equal(0);

    //     await fw.withdraw((await fw.balanceOf(a1.address)).div(2), usdt.address);

    //     await fw.connect(admin).reinvest();
    //     await fw.connect(admin).setMarketState(BULLISH);
    //     await fw.connect(admin).emergencyWithdraw();
    //     await fw.withdraw(await fw.balanceOf(a1.address), usdt.address);

    //     expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000').mul(99).div(100), getUsdtAmount('50000').div(100));
    //     expect(await fw.getAllPoolInUSD()).equal(0);
    //   });

    //   it("Withdraw before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('100000'));
    //     await usdt.transfer(a2.address, getUsdtAmount('100000'));
    //     await usdt.connect(a2).approve(fw.address, getUsdtAmount('100000'));

    //     await fw.connect(a2).deposit(getUsdtAmount('100000'), usdt.address);
    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.connect(admin).invest();
    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);

    //     expect(await fw.depositShare(a1.address)).gt(0);
    //     await fw.withdraw((await fw.depositShare(a1.address)).mul(3), usdt.address);
    //     expect(await fw.depositShare(a1.address)).equal(0);
    //     expect(await fw.balanceOf(a1.address)).equal(0);
    //     expect(await fw.getAllPoolInUSD()).gt(0);
    //     expect(await fw.getPricePerFullShare()).gt(parseEther('1'));
    //     expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('100000').mul(99).div(100), getUsdtAmount('100000').div(1000));
    //   });

    //   it("Withdraw after marketState changed", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('50000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('50000'));

    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     const fee = parseEther('50000').mul(100).div(PERC_DENOMINATOR)
    //     await fw.connect(admin).invest();

    //     await fw.connect(admin).setMarketState(BULLISH);
    //     expect(await fw.getAllPoolInUSD()).closeTo(parseEther('50000').sub(fee), parseEther('50000').sub(fee).div(1000));
    //     expect(await fw.getPricePerFullShare()).closeTo(parseEther('1'), parseEther('1').div(1000));
    //     expect(await fw.getAPR()).gte(0);
    //     expect(await fw.getPendingRewards()).gte(0);

    //     await fw.withdraw(await fw.balanceOf(a1.address), usdt.address);
    //     expect(await fw.totalSupply()).equal(0);
    //     expect(await fw.balanceOf(a1.address)).equal(0);
    //     expect(await fw.getAllPoolInUSD()).gte(0);
    //     expect(await fw.getPricePerFullShare()).gte(parseEther('1'));
    //     expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000').mul(99).div(100), getUsdtAmount('50000').div(1000));
    //   });

    //   it("Deposit with USDT, Withdraw as WBTC", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('50000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('50000'));

    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.connect(admin).invest();
    //     await fw.withdraw(await fw.balanceOf(a1.address), wbtc.address);

    //     const btcPriceInUSD = await btcFeed.latestAnswer();
    //     const btcAmount = getUsdtAmount('50000').mul(99).div(100).mul(e(10)).div(btcPriceInUSD);
    //     expect(await wbtc.balanceOf(a1.address)).closeTo(btcAmount, btcAmount.div(1000));
    //   });

    //   it("Deposit with USDT, Withdraw as USDT before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('100000'));

    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.connect(admin).invest();
    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.withdraw(await fw.balanceOf(a1.address), usdt.address);
    //     expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000').mul(99).div(100), getUsdtAmount('50000').div(1000));
    //   });

    //   it("Deposit with USDT, Withdraw as USDC before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('100000'));

    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.connect(admin).invest();
    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.withdraw(await fw.balanceOf(a1.address), usdc.address);
    //     expect(await usdc.balanceOf(a1.address)).closeTo(getUsdtAmount('50000').mul(99).div(100), getUsdtAmount('50000').div(1000));
    //   });

    //   it("Deposit with USDT, Withdraw as DAI before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('100000'));

    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.connect(admin).invest();
    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.withdraw(await fw.balanceOf(a1.address), dai.address);
    //     expect(await dai.balanceOf(a1.address)).closeTo(parseEther('50000').mul(99).div(100), parseEther('50000').div(1000));
    //   });

    //   it("Deposit with USDT, withdraw as WBTC before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('100000'));

    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.connect(admin).invest();
    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.withdraw(await fw.balanceOf(a1.address), wbtc.address);

    //     const btcPriceInUSD = await btcFeed.latestAnswer();
    //     const btcAmount = getUsdtAmount('50000').mul(99).div(100).mul(e(10)).div(btcPriceInUSD);
    //     expect(await wbtc.balanceOf(a1.address)).closeTo(btcAmount, btcAmount.div(1000));
    //   });

    //   it("Deposit with USDT, withdraw as SBTC before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('100000'));

    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.connect(admin).invest();
    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.withdraw(await fw.balanceOf(a1.address), sbtc.address);

    //     const btcPriceInUSD = await btcFeed.latestAnswer();
    //     const btcAmount = parseEther('50000').mul(99).div(100).mul(e(8)).div(btcPriceInUSD);
    //     expect(await sbtc.balanceOf(a1.address)).closeTo(btcAmount, btcAmount.div(1000));
    //   });

    //   it("Deposit with USDT, withdraw as RENBTC before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(fw.address, getUsdtAmount('100000'));

    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.connect(admin).invest();
    //     await fw.deposit(getUsdtAmount('50000'), usdt.address);
    //     await fw.withdraw(await fw.balanceOf(a1.address), renbtc.address);

    //     const btcPriceInUSD = await btcFeed.latestAnswer();
    //     const btcAmount = getUsdtAmount('50000').mul(99).div(100).mul(e(10)).div(btcPriceInUSD);
    //     expect(await renbtc.balanceOf(a1.address)).closeTo(btcAmount, btcAmount.div(1000));
    //   });
    // });

});