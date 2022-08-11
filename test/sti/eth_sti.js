const { expect } = require("chai");
const { assert, ethers, deployments, network } = require("hardhat");
const { expectRevert } = require('@openzeppelin/test-helpers');
const { BigNumber } = ethers;
const parseEther = ethers.utils.parseEther;
const { increaseTime, etherBalance, sendEth } = require("../../scripts/utils/ethereum");
const { executeMultisigTransaction } = require("../../scripts/utils/gnosis");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable.json").abi;
const StakeManager_ABI = [
  "function setCurrentEpoch(uint256 _currentEpoch) external",
  "function epoch() external view returns (uint256)",
  "function withdrawalDelay() external view returns (uint256)",
];
const Timelock_ABI = [
  "function grantRole(bytes32 role, address account)",
  "function schedule(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt, uint256 delay) external",
  "function execute(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt) external payable",
  "function getMinDelay() external view returns (uint256 duration)",
];

const { common, ethMainnet: network_ } = require("../../parameters");

const DAY = 24 * 3600;

function getUsdVaule(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}
function getUsdtAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}
function getMaticAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(18))
}
function e(decimals) {
  return BigNumber.from(10).pow(decimals)
}

async function grantTimelockRole() {
  const timelockIface = new ethers.utils.Interface(JSON.stringify(Timelock_ABI));
  const timelockAddr = "0xCaf0aa768A3AE1297DF20072419Db8Bb8b5C8cEf";
  const multiSigWalletAddr = "0xFa7D2a996aC6350f4b56C043112Da0366a59b74c";

  const timelockAdmin = await ethers.getSigner('0x427cEB53c3532835CcfdBbE4c533286e15d3576E');
  await network.provider.request({method: "hardhat_impersonateAccount", params: [timelockAdmin.address]});
  const timelock = new ethers.Contract("0xCaf0aa768A3AE1297DF20072419Db8Bb8b5C8cEf", Timelock_ABI, timelockAdmin);
  const delay = await timelock.getMinDelay();

  let proposerRoleData = timelockIface.encodeFunctionData("grantRole", ["0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1", timelockAdmin.address]); // PROPOSER_ROLE
  let proposerRoleData1 = timelockIface.encodeFunctionData("schedule", [
    timelockAddr, 0, proposerRoleData,
    "0x0000000000000000000000000000000000000000000000000000000000000000",
    "0x0000000000000000000000000000000000000000000000000000000000000000",
    delay
  ]);
  await executeMultisigTransaction(multiSigWalletAddr, timelockAddr, 0, proposerRoleData1);

  let executorRoleData = timelockIface.encodeFunctionData("grantRole", ["0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63", timelockAdmin.address]); // EXECUTOR_ROLE
  let executorRoleData1 = timelockIface.encodeFunctionData("schedule", [
    timelockAddr, 0, executorRoleData,
    "0x0000000000000000000000000000000000000000000000000000000000000000",
    "0x0000000000000000000000000000000000000000000000000000000000000000",
    delay
  ]);
  await executeMultisigTransaction(multiSigWalletAddr, timelockAddr, 0, executorRoleData1);

  await increaseTime(delay.toNumber());

  proposerRoleData1 = timelockIface.encodeFunctionData("execute", [
    timelockAddr, 0, proposerRoleData,
    "0x0000000000000000000000000000000000000000000000000000000000000000",
    "0x0000000000000000000000000000000000000000000000000000000000000000",
  ]);
  await executeMultisigTransaction(multiSigWalletAddr, timelockAddr, 0, proposerRoleData1);

  executorRoleData1 = timelockIface.encodeFunctionData("execute", [
    timelockAddr, 0, executorRoleData,
    "0x0000000000000000000000000000000000000000000000000000000000000000",
    "0x0000000000000000000000000000000000000000000000000000000000000000",
  ]);
  await executeMultisigTransaction(multiSigWalletAddr, timelockAddr, 0, executorRoleData1);
}

async function moveEpochToWithdraw(requestedEpoch) {
  const stakeManagerIface = new ethers.utils.Interface(JSON.stringify(StakeManager_ABI));
  const stakeManager = new ethers.Contract("0x5e3Ef299fDDf15eAa0432E6e66473ace8c13D908", StakeManager_ABI, deployer);
  const withdrawalDelay = await stakeManager.withdrawalDelay();
  const data = stakeManagerIface.encodeFunctionData("setCurrentEpoch", [withdrawalDelay.add(requestedEpoch)]);

  const Governance_ABI = [
    "function update(address target, bytes calldata data) external",
  ];
  const governanceIface = new ethers.utils.Interface(JSON.stringify(Governance_ABI));
  const governanceData = governanceIface.encodeFunctionData("update", [stakeManager.address, data]);

  const stMaticGovernanceAddr = "0x6e7a5820baD6cebA8Ef5ea69c0C92EbbDAc9CE48";

  const timelockAdmin = await ethers.getSigner('0x427cEB53c3532835CcfdBbE4c533286e15d3576E');
  const timelock = new ethers.Contract("0xCaf0aa768A3AE1297DF20072419Db8Bb8b5C8cEf", Timelock_ABI, timelockAdmin);
  const delay = await timelock.getMinDelay();

  await timelock.schedule(stMaticGovernanceAddr, 0, governanceData,
                  "0x0000000000000000000000000000000000000000000000000000000000000000",
                  "0x0000000000000000000000000000000000000000000000000000000000000000",
                  delay);

  await increaseTime(delay.toNumber());

  await timelock.execute(stMaticGovernanceAddr, 0, governanceData,
                  "0x0000000000000000000000000000000000000000000000000000000000000000",
                  "0x0000000000000000000000000000000000000000000000000000000000000000");
}

async function getCurrentEpoch() {
  const stakeManager = new ethers.Contract("0x5e3Ef299fDDf15eAa0432E6e66473ace8c13D908", StakeManager_ABI, deployer);
  return await stakeManager.epoch();
}

describe("STI on ETH", async () => {

    let vault, strategy, stVault, priceOracle, usdt, nft;
    let stMaticVault, stMaticNft;
    let vaultArtifact, strategyArtifact, stVaultArtifact, stMaticVaultArtifact, priceOracleArtifact, nftArtifact;
    let admin;

    before(async () => {
      [deployer, a1, a2, ...accounts] = await ethers.getSigners();
  
      vaultArtifact = await deployments.getArtifact("STIVault");
      strategyArtifact = await deployments.getArtifact("EthSTIStrategy");
      stVaultArtifact = await deployments.getArtifact("EthStETHVault");
      stMaticVaultArtifact = await deployments.getArtifact("EthStMATICVault");
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
      stMaticVault = new ethers.Contract(await strategy.MATICVault(), stMaticVaultArtifact.abi, a1);
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
        expect(await vault.trustedForwarder()).equal(network_.biconomy);
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
        await expectRevert(vault.setBiconomy(a2.address), "Ownable: caller is not the owner");
        await expectRevert(vault.depositByAdmin(a1.address, [a2.address], [getUsdVaule('100')], 1), "Only owner or admin");
        await expectRevert(vault.withdrawPercByAdmin(a1.address, parseEther('0.1'), 1), "Only owner or admin");
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

    describe('Basic function', () => {
      beforeEach(async () => {
        await vault.connect(deployer).setAdmin(accounts[0].address);
        await stVault.connect(deployer).setAdmin(accounts[0].address);
        await stMaticVault.connect(deployer).setAdmin(accounts[0].address);
        admin = accounts[0];

        await grantTimelockRole();
      });

      it("Basic Deposit/withdraw with small amount", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('100000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('100000'));

        const stETH = new ethers.Contract(network_.Token.stETH, ERC20_ABI, deployer);
        const MATIC = new ethers.Contract(network_.Token.MATIC, ERC20_ABI, deployer);
        const stMATIC = new ethers.Contract(network_.Token.stMATIC, ERC20_ABI, deployer);

        // deposit
        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdVaule('50000'),getUsdVaule('50000')], 1);

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('100000'), parseEther('100000').div(20));

        expect(await usdt.balanceOf(a1.address)).equal(0);
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await usdt.balanceOf(strategy.address)).equal(0);

        ret = await priceOracle.getAssetPrice(common.nativeAsset);
        const ETHPrice = ret[0];
        const ETHPriceDecimals = ret[1];
        const ETHAmt = getMaticAmount(1).mul(50000).div(ETHPrice).mul(e(ETHPriceDecimals));
        ret = await priceOracle.getAssetPrice(network_.Token.MATIC);
        const MATICPrice = ret[0];
        const MATICPriceDecimals = ret[1];
        const MATICAmt = getMaticAmount(1).mul(50000).div(MATICPrice).mul(e(MATICPriceDecimals));

        const ETHDeposits = await etherBalance(stVault.address);
        expect(await etherBalance(strategy.address)).equal(0);
        expect(ETHDeposits).closeTo(ETHAmt, ETHAmt.div(100));
        const MATICDeposits = await MATIC.balanceOf(stMaticVault.address);
        expect(await MATIC.balanceOf(strategy.address)).equal(0);
        expect(MATICDeposits).closeTo(MATICAmt, MATICAmt.div(10));

        expect(await stVault.bufferedDeposits()).closeTo(ETHDeposits, ETHDeposits.div(100));
        expect(await stVault.totalSupply()).closeTo(ETHDeposits, ETHDeposits.div(100));
        expect(await stMaticVault.bufferedDeposits()).equal(MATICDeposits);
        expect(await stMaticVault.totalSupply()).equal(MATICDeposits);

        // invest
        await stVault.connect(admin).invest();
        await stMaticVault.connect(admin).invest();

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('100000'), parseEther('100000').div(20));
        expect(await etherBalance(stVault.address)).lt(e(10));

        const stETHAmt = await stVault.getStTokenByPooledToken(ETHDeposits);
        const stETHBalance = await stETH.balanceOf(stVault.address);
        expect(stETHBalance).closeTo(stETHAmt, stETHAmt.div(50));
        expect(await stVault.getInvestedStTokens()).equal(0);
        expect(await stVault.bufferedDeposits()).lt(e(10));
        expect(await stVault.totalSupply()).closeTo(ETHDeposits, ETHDeposits.div(50));

        const stMATICAmt = await stMaticVault.getStTokenByPooledToken(MATICDeposits);
        const stMATICBalance = await stMATIC.balanceOf(stMaticVault.address);
        expect(stMATICBalance).closeTo(stMATICAmt, stMATICAmt.div(50));
        expect(await stMaticVault.getInvestedStTokens()).equal(0);
        expect(await stMaticVault.bufferedDeposits()).lt(e(10));
        expect(await stMaticVault.totalSupply()).equal(MATICDeposits);

        // withdraw all
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1'), 2);
        let usdtBalance = await usdt.balanceOf(a1.address);
        expect(usdtBalance).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(25));
        expect(await stVault.bufferedDeposits()).equal(0);
        expect(await nft.totalSupply()).equal(0);
        expect(await stVault.pendingRedeems()).equal(0);
        expect(await stVault.pendingWithdrawals()).equal(0);
        expect(await stMaticVault.bufferedDeposits()).equal(0);
        expect(await stMaticNft.totalSupply()).equal(1);
        expect(await stMaticNft.exists(1)).equal(true);
        expect(await stMaticNft.isApprovedOrOwner(strategy.address, 1)).equal(true);
        expect(await stMaticVault.pendingRedeems()).closeTo(stMATICBalance, stMATICBalance.div(100));
        expect(await stMaticVault.pendingWithdrawals()).closeTo(MATICDeposits, MATICDeposits.div(50));

        expect(await vault.getAllPoolInUSD()).equal(0);
        ret = await vault.getAllUnbonded(a1.address);
        let waitingInUSD = ret[0];
        let unbondedInUSD = ret[1];
        let waitForTs = ret[2];
        expect(waitingInUSD).gt(0);
        expect(unbondedInUSD).equal(0);
        const unbondingPeriod = await stMaticVault.unbondingPeriod();
        expect(waitForTs).closeTo(unbondingPeriod, unbondingPeriod.div(100));
        expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('100000'), getUsdtAmount('100000').div(10));

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
        expect(chainIDs.length).equal(2);
        expect(tokens[0]).equal(common.nativeAsset);
        expect(tokens[1]).equal(network_.Token.MATIC);
        expect(waitings[0]).equal(0);
        expect(waitings[1]).closeTo(MATICDeposits, MATICDeposits.div(50));
        expect(waitingInUSDs[0]).equal(0);
        expect(waitingInUSDs[1]).closeTo(parseEther('50000'), parseEther('50000').div(10));
        expect(unbondeds[0]).equal(0);
        expect(unbondeds[1]).equal(0);
        expect(unbondedInUSDs[0]).equal(0);
        expect(unbondedInUSDs[1]).equal(0);
        expect(waitForTses[0]).equal(0);
        expect(waitForTses[1]).closeTo(unbondingPeriod, unbondingPeriod.div(100));

        var ret = await vault.getAllUnbonded(a1.address);
        expect(waitingInUSDs[1]).equal(ret[0]);
        expect(unbondedInUSDs[1]).equal(ret[1]);
        expect(waitForTses[1]).equal(ret[2]);

        // redeem on stVault
        await stMaticVault.connect(admin).redeem();
        expect(await stMaticVault.pendingRedeems()).equal(0);
        expect(await stMaticVault.pendingWithdrawals()).closeTo(MATICDeposits, MATICDeposits.div(50));
        expect(await stMATIC.balanceOf(stMaticVault.address)).closeTo(BigNumber.from(10), 10);
        expect(await stMaticVault.first()).equal(await stMaticVault.last());

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
        expect(await stMaticVault.getTokenUnbonded()).equal(0);

        // update the epoch on the stakeManager instead Lido
        const epoch = await getCurrentEpoch();
        await moveEpochToWithdraw(epoch);

        // transfer MATIC to the stMATIC contract instead Lido.
        const UnstakedAmt = await stMaticVault.getPooledTokenByStToken(stMATICBalance);
        const matic = new ethers.Contract('0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0', ERC20_ABI, deployer);
        await matic.transfer(network_.Token.stMATIC, UnstakedAmt);
        expect(await stMaticVault.getTokenUnbonded()).equal(UnstakedAmt);

        ret = await vault.getAllUnbonded(a1.address);
        expect(ret[0]).gt(0);
        expect(ret[1]).equal(0);
        expect(ret[2]).equal(0);

        // claim the unbonded tokens on stVault
        await stMaticVault.connect(admin).claimUnbonded();
        expect(await stMaticVault.getTokenUnbonded()).equal(0);
        expect(await stMaticVault.first()).gt(await stMaticVault.last());

        ret = await vault.getAllUnbonded(a1.address);
        expect(ret[0]).equal(0);
        expect(ret[1]).gt(0);
        expect(ret[2]).equal(0);

        // claim the unbonded on vault;
        await vault.connect(a1).claim();
        expect(await stVault.pendingWithdrawals()).equal(0);
        expect(await stMaticVault.pendingWithdrawals()).equal(0);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('100000'), getUsdtAmount('100000').div(25));

        ret = await vault.getAllUnbonded(a1.address);
        expect(ret[0]).equal(0);
        expect(ret[1]).equal(0);
        expect(ret[2]).equal(0);
        expect(await nft.totalSupply()).equal(0);

        expect(await stVault.totalSupply()).equal(0);
        expect(await stMaticVault.totalSupply()).equal(0);
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await usdt.balanceOf(strategy.address)).equal(0);
        expect(await etherBalance(stVault.address)).equal(0);
        expect(await MATIC.balanceOf(stMaticVault.address)).closeTo(BigNumber.from(1),BigNumber.from(1));
        expect(await stETH.balanceOf(stVault.address)).closeTo(BigNumber.from(1),BigNumber.from(1));
        expect(await stMATIC.balanceOf(stMaticVault.address)).equal(0);
      });

      it("emergencyWithdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));
        await usdt.transfer(a2.address, getUsdtAmount('50000'));
        await usdt.connect(a2).approve(vault.address, getUsdtAmount('50000'));

        const stETH = new ethers.Contract(network_.Token.stETH, ERC20_ABI, deployer);
        const MATIC = new ethers.Contract(network_.Token.MATIC, ERC20_ABI, deployer);
        const stMATIC = new ethers.Contract(network_.Token.stMATIC, ERC20_ABI, deployer);

        // deposit
        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdVaule('25000'),getUsdVaule('25000')], 1);
        await stVault.connect(admin).invest();
        await stMaticVault.connect(admin).invest();
        await vault.connect(admin).depositByAdmin(a2.address, tokens, [getUsdVaule('25000'),getUsdVaule('25000')], 2);

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('100000'), parseEther('100000').div(20));

        ret = await priceOracle.getAssetPrice(common.nativeAsset);
        const ETHPrice = ret[0];
        const ETHPriceDecimals = ret[1];
        const ETHAmt = getMaticAmount(1).mul(25000).div(ETHPrice).mul(e(ETHPriceDecimals));
        ret = await priceOracle.getAssetPrice(network_.Token.MATIC);
        const MATICPrice = ret[0];
        const MATICPriceDecimals = ret[1];
        const MATICAmt = getMaticAmount(1).mul(25000).div(MATICPrice).mul(e(MATICPriceDecimals));

        const ETHDeposits = await etherBalance(stVault.address);
        expect(await etherBalance(strategy.address)).equal(0);
        expect(ETHDeposits).closeTo(ETHAmt, ETHAmt.div(100));
        const MATICDeposits = await MATIC.balanceOf(stMaticVault.address);
        expect(await MATIC.balanceOf(strategy.address)).equal(0);
        expect(MATICDeposits).closeTo(MATICAmt, MATICAmt.div(5));

        expect(await stVault.bufferedDeposits()).equal(ETHDeposits);
        expect(await stVault.totalSupply()).closeTo(ETHDeposits.mul(2), ETHDeposits.mul(2).div(50));
        expect(await stMaticVault.bufferedDeposits()).equal(MATICDeposits);
        expect(await stMaticVault.totalSupply()).closeTo(MATICDeposits.mul(2), MATICDeposits.mul(2).div(20));

        const stETHAmt = await stVault.getStTokenByPooledToken(ETHDeposits);
        const stETHBalance = await stETH.balanceOf(stVault.address);
        expect(stETHBalance).closeTo(stETHAmt, stETHAmt.div(50));
        const stMATICAmt = await stMaticVault.getStTokenByPooledToken(MATICDeposits);
        const stMATICBalance = await stMATIC.balanceOf(stMaticVault.address);
        expect(stMATICBalance).closeTo(stMATICAmt, stMATICAmt.div(10));

        // emergencyWithdraw before investment
        await vault.connect(admin).emergencyWithdraw();

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('100000'), parseEther('100000').div(20));
        expect(await stVault.totalSupply()).equal(0);
        expect(await stVault.pendingRedeems()).equal(0);
        expect(await stVault.pendingWithdrawals()).equal(0);
        expect(await nft.totalSupply()).equal(0);
        expect(await stMaticVault.totalSupply()).equal(0);
        expect(await stMaticVault.pendingRedeems()).closeTo(stMATICBalance, stMATICBalance.div(100));
        expect(await stMaticVault.pendingWithdrawals()).closeTo(stMATICAmt, stMATICAmt.div(5));
        expect(await stMaticNft.totalSupply()).equal(1);
        expect(await usdt.balanceOf(vault.address)).closeTo(getUsdtAmount('75000'), getUsdtAmount('75000').div(20));

        ret = await vault.getEmergencyWithdrawalUnbonded();
        let waitingInUSD = ret[0];
        let unbondedInUSD = ret[1];
        let waitForTs = ret[2];
        expect(waitingInUSD).closeTo(parseEther('25000'), parseEther('25000').div(10));
        expect(unbondedInUSD).equal(0);
        const unbondingPeriod = await stMaticVault.unbondingPeriod();
        expect(waitForTs).closeTo(unbondingPeriod, unbondingPeriod.div(100));

        await expectRevert(vault.connect(admin).depositByAdmin(a2.address, tokens, [getUsdVaule('10000')], 3), "Pausable: paused");
        await expectRevert(vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(4).div(5), 3), "Retry after all claimed");

        // withdraw a little of amount
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').div(10), 3);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('10000'), getUsdtAmount('10000').div(20));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('90000'), parseEther('90000').div(20));

        // redeem on stVault
        await stMaticVault.connect(admin).redeem();

        await increaseTime(unbondingPeriod.toNumber());
        // update the epoch on the stakeManager instead Lido
        const epoch = await getCurrentEpoch();
        await moveEpochToWithdraw(epoch);

        // transfer MATIC to the stMATIC contract instead Lido.
        const UnstakedAmt = await stMaticVault.getPooledTokenByStToken(stMATICBalance);
        const matic = new ethers.Contract('0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0', ERC20_ABI, deployer);
        await matic.transfer(network_.Token.stMATIC, UnstakedAmt);
        expect(await stMaticVault.getTokenUnbonded()).equal(UnstakedAmt);

        // claim the unbonded tokens on stVault
        await stMaticVault.connect(admin).claimUnbonded();
        expect(await stMaticVault.getTokenUnbonded()).equal(0);
        expect(await stMaticVault.first()).gt(await stMaticVault.last());

        ret = await vault.getEmergencyWithdrawalUnbonded();
        waitingInUSD = ret[0];
        unbondedInUSD = ret[1];
        waitForTs = ret[2];
        expect(waitingInUSD).equal(0);
        expect(unbondedInUSD).closeTo(parseEther('25000'), parseEther('25000').div(20));
        expect(waitForTs).equal(0);

        // claim the emergency withdrawal
        await vault.connect(admin).claimEmergencyWithdrawal();

        ret = await vault.getEmergencyWithdrawalUnbonded();
        expect(ret[1]).equal(0);
        expect(await stMaticVault.pendingRedeems()).equal(0);
        expect(await stMaticVault.pendingWithdrawals()).equal(0);
        expect(await stMaticNft.totalSupply()).equal(0);
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('90000'), parseEther('90000').div(20));
        expect(await usdt.balanceOf(vault.address)).closeTo(getUsdtAmount('90000'), getUsdtAmount('90000').div(20));

        // withdraw rest of a1's deposit
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(4).div(9), 4);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(25));
        expect(await usdt.balanceOf(vault.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(20));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(20));

        // reinvest
        ret = await vault.getCurrentCompositionPerc();
        await vault.connect(admin).reinvest(ret[0], ret[1]);

        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(20));
        expect(await usdt.balanceOf(vault.address)).closeTo(BigNumber.from(1),BigNumber.from(1));
        expect(await etherBalance(stVault.address)).closeTo(ETHDeposits, ETHDeposits.div(20));
        expect(await stVault.bufferedDeposits()).equal(await etherBalance(stVault.address));
        expect(await stVault.totalSupply()).closeTo(ETHDeposits, ETHDeposits.div(20));
        expect(await MATIC.balanceOf(stMaticVault.address)).closeTo(MATICDeposits, MATICDeposits.div(10));
        expect(await stMaticVault.bufferedDeposits()).closeTo(MATICDeposits, MATICDeposits.div(10));
        expect(await stMaticVault.totalSupply()).closeTo(MATICDeposits, MATICDeposits.div(10));

        await increaseTime(5*60);
        await stVault.connect(admin).invest();
        await stMaticVault.connect(admin).invest();
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(20));
        expect(await etherBalance(stVault.address)).lt(e(10));
        expect(await stETH.balanceOf(stVault.address)).closeTo(stETHBalance, stETHBalance.div(50));
        expect(await MATIC.balanceOf(stMaticVault.address)).equal(0);
        expect(await stMATIC.balanceOf(stMaticVault.address)).closeTo(stMATICBalance, stMATICBalance.div(20));
      });
    });

    describe('EthStMATICVault', () => {
      beforeEach(async () => {
        await vault.connect(deployer).setAdmin(accounts[0].address);
        await stMaticVault.connect(deployer).setAdmin(accounts[0].address);
        admin = accounts[0];

        await grantTimelockRole();
      });

      it("emergencyWithdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        const MATIC = new ethers.Contract(network_.Token.MATIC, ERC20_ABI, deployer);
        const stMATIC = new ethers.Contract(network_.Token.stMATIC, ERC20_ABI, deployer);

        // deposit & invest
        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdVaule('25000'),getUsdVaule('25000')], 1);
        const MATICDeposits = await MATIC.balanceOf(stMaticVault.address);

        await stMaticVault.connect(admin).invest();
        const stMATICBalance = await stMATIC.balanceOf(stMaticVault.address);

        // emergency on stVault
        await stMaticVault.connect(admin).emergencyWithdraw();
        expect(await stMaticVault.first()).equal(await stMaticVault.last());

        expect(await MATIC.balanceOf(stMaticVault.address)).equal(0);
        expect(await stMATIC.balanceOf(stMaticVault.address)).equal(0);
        expect(await stMaticVault.pendingWithdrawals()).equal(0);
        expect(await stMaticVault.totalSupply()).equal(MATICDeposits);
        expect(await stMaticVault.getEmergencyUnbondings()).equal(stMATICBalance);

        // withdraw 20000 USD
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(2).div(5), 2);
        let usdtBalance = await usdt.balanceOf(a1.address);
        expect(usdtBalance).closeTo(getUsdtAmount('10000'), getUsdtAmount('10000').div(20));
        expect(await stMaticNft.totalSupply()).equal(1);
        expect(await stMaticNft.exists(1)).equal(true);
        expect(await stMaticNft.isApprovedOrOwner(strategy.address, 1)).equal(true);
        expect(await stMaticVault.pendingRedeems()).equal(0);
        expect(await stMaticVault.pendingWithdrawals()).closeTo(MATICDeposits.mul(2).div(5), MATICDeposits.mul(2).div(5).div(50));
        expect(await stMaticVault.totalSupply()).closeTo(MATICDeposits.mul(3).div(5), MATICDeposits.mul(3).div(5).div(50));
        expect(await stMaticVault.getEmergencyUnbondings()).closeTo(stMATICBalance.mul(3).div(5), stMATICBalance.mul(3).div(5).div(50));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('30000'), parseEther('30000').div(20));
        ret = await vault.getAllUnbonded(a1.address);
        let waitingInUSD = ret[0];
        let unbondedInUSD = ret[1];
        let waitForTs = ret[2];
        expect(waitingInUSD).closeTo(parseEther('10000'), parseEther('10000').div(20));
        expect(unbondedInUSD).equal(0);
        expect(waitForTs).gt(0);
        expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('20000'), getUsdtAmount('20000').div(20));

        // withdraw again 20000 USD
        await increaseTime(DAY);
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(2).div(3), 3);
        usdtBalance = await usdt.balanceOf(a1.address);
        expect(usdtBalance).closeTo(getUsdtAmount('20000'), getUsdtAmount('20000').div(20));
        expect(await stMaticNft.totalSupply()).equal(2);
        expect(await stMaticNft.exists(2)).equal(true);
        expect(await stMaticNft.isApprovedOrOwner(strategy.address, 2)).equal(true);
        expect(await stMaticVault.pendingRedeems()).equal(0);
        expect(await stMaticVault.pendingWithdrawals()).closeTo(MATICDeposits.mul(4).div(5), MATICDeposits.mul(4).div(5).div(50));
        expect(await stMaticVault.totalSupply()).closeTo(MATICDeposits.div(5), MATICDeposits.div(5).div(50));
        expect(await stMaticVault.getEmergencyUnbondings()).closeTo(stMATICBalance.div(5), stMATICBalance.div(5).div(50));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('10000'), parseEther('10000').div(25));
        ret = await vault.getAllUnbonded(a1.address);
        waitingInUSD = ret[0];
        unbondedInUSD = ret[1];
        expect(waitingInUSD).closeTo(parseEther('20000'), parseEther('20000').div(20));
        expect(unbondedInUSD).equal(0);
        expect(ret[2]).lt(waitForTs);
        expect(usdtBalance.add(waitingInUSD.div(e(12)))).closeTo(getUsdtAmount('40000'), getUsdtAmount('40000').div(20));

        await expectRevert(stMaticVault.connect(admin).reinvest(), "Emergency unbonding is not finished");

        const unbondingPeriod = await stMaticVault.unbondingPeriod();
        await increaseTime(unbondingPeriod.toNumber());
        // update the epoch on the stakeManager instead Lido
        var epoch = await getCurrentEpoch();
        await moveEpochToWithdraw(epoch);

        // transfer MATIC to the stMATIC contract instead Lido.
        var UnstakedAmt = await stMaticVault.getPooledTokenByStToken(stMATICBalance);
        await MATIC.transfer(network_.Token.stMATIC, UnstakedAmt);

        expect(await stMaticVault.getTokenUnbonded()).equal(UnstakedAmt);
        ret = await vault.getAllUnbonded(a1.address);
        expect(ret[0]).closeTo(parseEther('20000'), parseEther('20000').div(20));
        expect(ret[1]).equal(0);

        // claim the unbonded tokens on stVault
        await stMaticVault.connect(admin).claimUnbonded();
        expect(await stMaticVault.getEmergencyUnbondings()).equal(0);
        expect(await stMaticVault.getTokenUnbonded()).equal(0);
        expect(await MATIC.balanceOf(stMaticVault.address)).equal(UnstakedAmt);
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('10000'), parseEther('10000').div(25));

        ret = await vault.getAllUnbonded(a1.address);
        expect(ret[0]).equal(0);
        expect(ret[1]).closeTo(parseEther('20000'), parseEther('20000').div(20));

        // reinvest on stVault
        await stMaticVault.connect(admin).reinvest();
        expect(await MATIC.balanceOf(stMaticVault.address)).gt(0);
        expect(await stMaticVault.getAllPoolInUSD()).closeTo(parseEther('5000'), parseEther('5000').div(20));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('10000'), parseEther('10000').div(25));

        // claim the unbonded token for a1
        await vault.connect(admin).claimByAdmin(a1.address);
        expect(await MATIC.balanceOf(stMaticVault.address)).equal(0);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('40000'), getUsdtAmount('40000').div(20));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('10000'), parseEther('10000').div(25));

        // withdraw all
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1'), 4);
        await stMaticVault.connect(admin).redeem();
        expect(await vault.getAllPoolInUSD()).equal(0);
        ret = await vault.getAllUnbonded(a1.address);
        expect(ret[0]).closeTo(parseEther('5000'), parseEther('5000').div(20));

        await increaseTime(unbondingPeriod.toNumber());
        // update the epoch on the stakeManager instead Lido
        epoch = await getCurrentEpoch();
        await moveEpochToWithdraw(epoch);

        // transfer MATIC to the stMATIC contract instead Lido.
        UnstakedAmt = await stMaticVault.getPooledTokenByStToken(stMATICBalance);
        await MATIC.transfer(network_.Token.stMATIC, UnstakedAmt);

        // claim the unbonded tokens on stVault
        await stMaticVault.connect(admin).claimUnbonded();

        await vault.connect(admin).claimByAdmin(a1.address);

        expect(await stMaticNft.totalSupply()).equal(0);
        expect(await stMaticVault.totalSupply()).equal(0);
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await usdt.balanceOf(strategy.address)).equal(0);
        expect(await MATIC.balanceOf(strategy.address)).equal(0);
        expect(await MATIC.balanceOf(stMaticVault.address)).closeTo(BigNumber.from(1),BigNumber.from(1));
        expect(await stMATIC.balanceOf(stMaticVault.address)).equal(0);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(25));
      });
    });

    describe('EthStETHVault', () => {
      beforeEach(async () => {
        await vault.connect(deployer).setAdmin(accounts[0].address);
        await stVault.connect(deployer).setAdmin(accounts[0].address);
        admin = accounts[0];

        await grantTimelockRole();
      });

      it("emergencyWithdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        const stETH = new ethers.Contract(network_.Token.stETH, ERC20_ABI, deployer);
        const MATIC = new ethers.Contract(network_.Token.MATIC, ERC20_ABI, deployer);

        // deposit & invest
        var ret = await vault.getEachPoolInUSD();
        var tokens = ret[1];
        await vault.connect(admin).depositByAdmin(a1.address, tokens, [getUsdVaule('25000'),getUsdVaule('25000')], 1);
        const ETHDeposits = await etherBalance(stVault.address);
        const MATICDeposits = await MATIC.balanceOf(stMaticVault.address);

        await stVault.connect(admin).invest();
        expect(await stVault.bufferedDeposits()).equal(0);
        const stETHBalance = await stETH.balanceOf(stVault.address);
        // Do not invest on stMaticVault because we test on only stVault

        // emergency on stVault
        await stVault.connect(admin).emergencyWithdraw();

        expect(await etherBalance(stVault.address)).closeTo(ETHDeposits,ETHDeposits.div(5));
        expect(await stETH.balanceOf(stVault.address)).closeTo(BigNumber.from(1),BigNumber.from(1));
        expect(await stVault.pendingWithdrawals()).equal(0);
        expect(await stVault.totalSupply()).closeTo(ETHDeposits,ETHDeposits.div(50));
        expect(await stVault.getEmergencyUnbondings()).equal(0);

        expect(await stVault.totalSupply()).closeTo(ETHDeposits, ETHDeposits.div(100));
        expect(await stMaticVault.bufferedDeposits()).equal(MATICDeposits);
        expect(await stMaticVault.totalSupply()).equal(MATICDeposits);

        // withdraw 20000 USD
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(2).div(5), 2);
        let usdtBalance = await usdt.balanceOf(a1.address);
        expect(usdtBalance).closeTo(getUsdtAmount('20000'), getUsdtAmount('20000').div(20));
        expect(await nft.totalSupply()).equal(0);
        expect(await stVault.pendingRedeems()).equal(0);
        expect(await stVault.pendingWithdrawals()).equal(0);
        expect(await stVault.totalSupply()).closeTo(ETHDeposits.mul(3).div(5), ETHDeposits.mul(3).div(5).div(50));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('30000'), parseEther('30000').div(20));
        ret = await vault.getAllUnbonded(a1.address);
        expect(ret[0]).equal(0);
        expect(ret[1]).equal(0);
        expect(ret[2]).equal(0);

        // withdraw again 20000 USD
        await increaseTime(DAY);
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1').mul(2).div(3), 3);
        usdtBalance = await usdt.balanceOf(a1.address);
        expect(usdtBalance).closeTo(getUsdtAmount('40000'), getUsdtAmount('40000').div(20));
        expect(await stVault.totalSupply()).closeTo(ETHDeposits.div(5), ETHDeposits.div(5).div(50));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('10000'), parseEther('10000').div(25));

        // reinvest on stVault
        await stVault.connect(admin).reinvest();
        expect(await etherBalance(stVault.address)).equal(0);
        expect(await stETH.balanceOf(stVault.address)).closeTo(stETHBalance.div(5), stETHBalance.div(5).div(20));
        expect(await stVault.getAllPoolInUSD()).closeTo(parseEther('5000'), parseEther('5000').div(20));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('10000'), parseEther('10000').div(25));

        // withdraw all
        await vault.connect(admin).withdrawPercByAdmin(a1.address, parseEther('1'), 4);
        expect(await vault.getAllPoolInUSD()).equal(0);

        expect(await nft.totalSupply()).equal(0);
        expect(await stVault.totalSupply()).equal(0);
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await usdt.balanceOf(strategy.address)).equal(0);
        expect(await etherBalance(strategy.address)).equal(0);
        expect(await etherBalance(stVault.address)).equal(0);
        expect(await stETH.balanceOf(stVault.address)).closeTo(BigNumber.from(1),BigNumber.from(1));
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(25));
      });
    });

});