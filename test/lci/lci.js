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
function getUsdtAmount(amount) {
  return parseEther(amount);
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

        await expectRevert(vault.emergencyWithdraw(), "Only owner or admin");
        await vault.connect(admin).emergencyWithdraw();
        await expectRevert(vault.connect(deployer).emergencyWithdraw(), "Pausable: paused");

        await expectRevert(vault.reinvest(), "Only owner or admin");
        await vault.connect(admin).reinvest();
        await expectRevert(vault.connect(deployer).reinvest(), "Pausable: not paused");

        await expectRevert(vault.rebalance(0, 1000), "Only owner or admin");
        await vault.connect(admin).rebalance(0, 1000);

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
      it("Deposit/withdraw", async () => {
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
        expect(await vault.balanceOf(a1.address)).equal(parseEther('50000'));
        expect(await vault.totalSupply()).equal(parseEther('50000'));
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
        expect(await vault.getAllPoolInUSD()).gte(0);
        expect(await vault.getPricePerFullShare()).gte(parseEther('1'));
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(100));
      });

    //   it("Test Deposit fee", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('5000000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('5000000'));

    //     await vault.deposit(getUsdtAmount('100000'), usdt.address);
    //     var fee = parseEther('100000').mul(75).div(PERC_DENOMINATOR)
    //     expect(await vault.depositAmt(a1.address)).equal(parseEther('100000').sub(fee));
    //     expect(await vault.totalDepositAmt()).equal(parseEther('100000').sub(fee));
    //     expect(await vault.fees()).equal(fee);
    //     await vault.connect(admin).invest();
    //     await vault.withdraw(await vault.balanceOf(a1.address), usdt.address);

    //     await vault.deposit(getUsdtAmount('1000000'), usdt.address);
    //     var fee = parseEther('1000000').mul(50).div(PERC_DENOMINATOR)
    //     expect(await vault.depositAmt(a1.address)).equal(parseEther('1000000').sub(fee));
    //     expect(await vault.totalDepositAmt()).equal(parseEther('1000000').sub(fee));
    //     expect(await vault.fees()).equal(fee);
    //     await vault.connect(admin).invest();
    //     await vault.withdraw(await vault.balanceOf(a1.address), usdt.address);

    //     await vault.deposit(getUsdtAmount('1000001'), usdt.address);
    //     var fee = parseEther('1000001').mul(25).div(PERC_DENOMINATOR)
    //     expect(await vault.depositAmt(a1.address)).equal(parseEther('1000001').sub(fee));
    //     expect(await vault.totalDepositAmt()).equal(parseEther('1000001').sub(fee));
    //     expect(await vault.fees()).equal(fee);
    //     await vault.connect(admin).invest();
    //     await vault.withdraw(await vault.balanceOf(a1.address), usdt.address);
    //   });

    //   it("Deposit again before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('100000'));

    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     const fee = parseEther('50000').mul(100).div(PERC_DENOMINATOR)
    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     expect(await vault.depositAmt(a1.address)).equal(parseEther('50000').sub(fee).mul(2));
    //     expect(await vault.totalDepositAmt()).equal(parseEther('50000').sub(fee).mul(2));
    //     expect(await vault.fees()).equal(fee.mul(2));
    //     expect(await vault.getTotalPendingDeposits()).equal(1);
    //     expect(await vault.totalSupply()).equal(0);
    //     expect(await vault.getAllPoolInUSD()).equal(parseEther('50000').sub(fee).mul(2));
    //     expect(await vault.getPricePerFullShare()).equal(parseEther('1'));

    //     const treasuryBalanceBefore = await usdt.balanceOf(network_.treasury);
    //     await vault.connect(admin).invest();
    //     expect((await usdt.balanceOf(network_.treasury)).sub(treasuryBalanceBefore)).equal(getUsdtAmount('100000').mul(100).div(PERC_DENOMINATOR));
    //     expect(await vault.depositAmt(a1.address)).equal(0);
    //     expect(await vault.totalDepositAmt()).equal(0);
    //     expect(await vault.fees()).equal(0);
    //     expect(await vault.getTotalPendingDeposits()).equal(0);
    //     expect(await vault.totalSupply()).equal(parseEther('50000').sub(fee).mul(2));
    //     expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000').sub(fee).mul(2), parseEther('50000').sub(fee).mul(2).div(100));
    //     expect(await vault.balanceOf(a1.address)).equal(parseEther('50000').sub(fee).mul(2));
    //   });

    //   it("Deposit again after invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('100000'));

    //     const treasuryBalanceBefore = await usdt.balanceOf(network_.treasury);
    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     const fee = parseEther('50000').mul(100).div(PERC_DENOMINATOR)
    //     await vault.connect(admin).invest();

    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.connect(admin).invest();
    //     expect((await usdt.balanceOf(network_.treasury)).sub(treasuryBalanceBefore)).equal(getUsdtAmount('100000').mul(100).div(PERC_DENOMINATOR));
    //     expect(await vault.depositAmt(a1.address)).equal(0);
    //     expect(await vault.totalDepositAmt()).equal(0);
    //     expect(await vault.fees()).equal(0);
    //     expect(await vault.getTotalPendingDeposits()).equal(0);
    //     expect(await vault.totalSupply()).closeTo(parseEther('50000').sub(fee).mul(2), parseEther('50000').sub(fee).mul(2).div(100));
    //     expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000').sub(fee).mul(2), parseEther('50000').sub(fee).mul(2).div(100));
    //     expect(await vault.balanceOf(a1.address)).closeTo(parseEther('50000').sub(fee).mul(2), parseEther('50000').sub(fee).mul(2).div(100));
    //   });

    //   it("Test emergencyWithdraw", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('50000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     const fee = parseEther('50000').mul(100).div(PERC_DENOMINATOR)

    //     await vault.connect(admin).emergencyWithdraw();
    //     expect(await vault.getAllPoolInUSD()).equal(parseEther('50000').sub(fee));
    //     await vault.connect(admin).reinvest();
    //     expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000').sub(fee), parseEther('50000').sub(fee).div(1000));
    //     await vault.connect(admin).emergencyWithdraw();
    //     expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000').sub(fee), parseEther('50000').sub(fee).div(1000));

    //     expect(await vault.getPricePerFullShare()).closeTo(parseEther('1'), parseEther('1').div(1000));
    //     expect(await vault.getAPR()).equal(0);
    //     expect(await vault.getPendingRewards()).equal(0);

    //     await vault.withdraw((await vault.balanceOf(a1.address)).div(2), usdt.address);

    //     await vault.connect(admin).reinvest();
    //     await vault.connect(admin).setMarketState(BULLISH);
    //     await vault.connect(admin).emergencyWithdraw();
    //     await vault.withdraw(await vault.balanceOf(a1.address), usdt.address);

    //     expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000').mul(99).div(100), getUsdtAmount('50000').div(100));
    //     expect(await vault.getAllPoolInUSD()).equal(0);
    //   });

    //   it("Withdraw before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('100000'));
    //     await usdt.transfer(a2.address, getUsdtAmount('100000'));
    //     await usdt.connect(a2).approve(vault.address, getUsdtAmount('100000'));

    //     await vault.connect(a2).deposit(getUsdtAmount('100000'), usdt.address);
    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.connect(admin).invest();
    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);

    //     expect(await vault.depositShare(a1.address)).gt(0);
    //     await vault.withdraw((await vault.depositShare(a1.address)).mul(3), usdt.address);
    //     expect(await vault.depositShare(a1.address)).equal(0);
    //     expect(await vault.balanceOf(a1.address)).equal(0);
    //     expect(await vault.getAllPoolInUSD()).gt(0);
    //     expect(await vault.getPricePerFullShare()).gt(parseEther('1'));
    //     expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('100000').mul(99).div(100), getUsdtAmount('100000').div(1000));
    //   });

    //   it("Withdraw after marketState changed", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('50000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     const fee = parseEther('50000').mul(100).div(PERC_DENOMINATOR)
    //     await vault.connect(admin).invest();

    //     await vault.connect(admin).setMarketState(BULLISH);
    //     expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000').sub(fee), parseEther('50000').sub(fee).div(1000));
    //     expect(await vault.getPricePerFullShare()).closeTo(parseEther('1'), parseEther('1').div(1000));
    //     expect(await vault.getAPR()).gte(0);
    //     expect(await vault.getPendingRewards()).gte(0);

    //     await vault.withdraw(await vault.balanceOf(a1.address), usdt.address);
    //     expect(await vault.totalSupply()).equal(0);
    //     expect(await vault.balanceOf(a1.address)).equal(0);
    //     expect(await vault.getAllPoolInUSD()).gte(0);
    //     expect(await vault.getPricePerFullShare()).gte(parseEther('1'));
    //     expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000').mul(99).div(100), getUsdtAmount('50000').div(1000));
    //   });

    //   it("Deposit with USDT, Withdraw as WBTC", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('50000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.connect(admin).invest();
    //     await vault.withdraw(await vault.balanceOf(a1.address), wbtc.address);

    //     const btcPriceInUSD = await btcFeed.latestAnswer();
    //     const btcAmount = getUsdtAmount('50000').mul(99).div(100).mul(e(10)).div(btcPriceInUSD);
    //     expect(await wbtc.balanceOf(a1.address)).closeTo(btcAmount, btcAmount.div(1000));
    //   });

    //   it("Deposit with USDT, Withdraw as USDT before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('100000'));

    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.connect(admin).invest();
    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.withdraw(await vault.balanceOf(a1.address), usdt.address);
    //     expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000').mul(99).div(100), getUsdtAmount('50000').div(1000));
    //   });

    //   it("Deposit with USDT, Withdraw as USDC before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('100000'));

    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.connect(admin).invest();
    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.withdraw(await vault.balanceOf(a1.address), usdc.address);
    //     expect(await usdc.balanceOf(a1.address)).closeTo(getUsdtAmount('50000').mul(99).div(100), getUsdtAmount('50000').div(1000));
    //   });

    //   it("Deposit with USDT, Withdraw as DAI before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('100000'));

    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.connect(admin).invest();
    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.withdraw(await vault.balanceOf(a1.address), dai.address);
    //     expect(await dai.balanceOf(a1.address)).closeTo(parseEther('50000').mul(99).div(100), parseEther('50000').div(1000));
    //   });

    //   it("Deposit with USDT, withdraw as WBTC before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('100000'));

    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.connect(admin).invest();
    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.withdraw(await vault.balanceOf(a1.address), wbtc.address);

    //     const btcPriceInUSD = await btcFeed.latestAnswer();
    //     const btcAmount = getUsdtAmount('50000').mul(99).div(100).mul(e(10)).div(btcPriceInUSD);
    //     expect(await wbtc.balanceOf(a1.address)).closeTo(btcAmount, btcAmount.div(1000));
    //   });

    //   it("Deposit with USDT, withdraw as SBTC before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('100000'));

    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.connect(admin).invest();
    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.withdraw(await vault.balanceOf(a1.address), sbtc.address);

    //     const btcPriceInUSD = await btcFeed.latestAnswer();
    //     const btcAmount = parseEther('50000').mul(99).div(100).mul(e(8)).div(btcPriceInUSD);
    //     expect(await sbtc.balanceOf(a1.address)).closeTo(btcAmount, btcAmount.div(1000));
    //   });

    //   it("Deposit with USDT, withdraw as RENBTC before invest", async () => {
    //     await usdt.transfer(a1.address, getUsdtAmount('100000'));
    //     await usdt.connect(a1).approve(vault.address, getUsdtAmount('100000'));

    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.connect(admin).invest();
    //     await vault.deposit(getUsdtAmount('50000'), usdt.address);
    //     await vault.withdraw(await vault.balanceOf(a1.address), renbtc.address);

    //     const btcPriceInUSD = await btcFeed.latestAnswer();
    //     const btcAmount = getUsdtAmount('50000').mul(99).div(100).mul(e(10)).div(btcPriceInUSD);
    //     expect(await renbtc.balanceOf(a1.address)).closeTo(btcAmount, btcAmount.div(1000));
    //   });
    });

});