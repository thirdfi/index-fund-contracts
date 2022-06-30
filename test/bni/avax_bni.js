const { expect } = require("chai");
const { assert, ethers, deployments } = require("hardhat");
const { expectRevert } = require('@openzeppelin/test-helpers');
const { BigNumber } = ethers;
const parseEther = ethers.utils.parseEther;
const AddressZero = ethers.constants.AddressZero;
const { increaseTime } = require("../../scripts/utils/ethereum");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable.json").abi;

const { common, avaxMainnet: network_ } = require("../../parameters");

const DAY = 24 * 3600;

function getUsdtAmount(amount) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(6))
}

describe("BNI on Avalanche", async () => {

    let bni, minter, vault, strategy, priceOracle, usdt;
    let bniArtifact, minterArtifact, vaultArtifact, strategyArtifact, l2VaultArtifact;
    let admin;

    before(async () => {
      [deployer, a1, a2, ...accounts] = await ethers.getSigners();
  
      bniArtifact = await deployments.getArtifact("BNI");
      minterArtifact = await deployments.getArtifact("BNIMinter");
      vaultArtifact = await deployments.getArtifact("BNIVault");
      strategyArtifact = await deployments.getArtifact("AvaxBNIStrategy");
      priceOracleArtifact = await deployments.getArtifact("AvaxPriceOracle");
      l2VaultArtifact = await deployments.getArtifact("Aave3Vault");
    });
  
    beforeEach(async () => {
      await deployments.fixture(["hardhat_avax_bni"])

      const bniProxy = await ethers.getContract("BNI_Proxy");
      bni = new ethers.Contract(bniProxy.address, bniArtifact.abi, a1);
      const minterProxy = await ethers.getContract("BNIMinter_Proxy");
      minter = new ethers.Contract(minterProxy.address, minterArtifact.abi, a1);
      const vaultProxy = await ethers.getContract("BNIVault_Proxy");
      vault = new ethers.Contract(vaultProxy.address, vaultArtifact.abi, a1);
      const strategyProxy = await ethers.getContract("AvaxBNIStrategy_Proxy");
      strategy = new ethers.Contract(strategyProxy.address, strategyArtifact.abi, a1);
      const priceOracleProxy = await ethers.getContract("AvaxPriceOracle_Proxy");
      priceOracle = new ethers.Contract(priceOracleProxy.address, priceOracleArtifact.abi, a1);

      admin = await ethers.getSigner(common.admin);

      usdt = new ethers.Contract(network_.Swap.USDT, ERC20_ABI, deployer);
    });

    describe('Basic', () => {
      it("Should be set with correct initial vaule", async () => {
        expect(await priceOracle.owner()).equal(deployer.address);

        expect(await bni.owner()).equal(deployer.address);
        expect(await bni.name()).equal('Blockchain Network Index');
        expect(await bni.symbol()).equal('BNI');
        expect(await bni.minter()).equal(minter.address);

        expect(await minter.owner()).equal(deployer.address);
        expect(await minter.admin()).equal(common.admin);
        expect(await minter.BNI()).equal(bni.address);
        expect(await minter.priceOracle()).equal(priceOracle.address);
        expect(await minter.chainIDs(0)).equal(137);
        expect(await minter.chainIDs(1)).equal(43114);
        expect(await minter.chainIDs(2)).equal(1313161554);
        expect(await minter.tokens(0)).equal('0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270');
        expect(await minter.tokens(1)).equal('0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7');
        expect(await minter.tokens(2)).equal('0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d');
        expect(await minter.targetPercentages(0)).equal(4000);
        expect(await minter.targetPercentages(1)).equal(4000);
        expect(await minter.targetPercentages(2)).equal(2000);
        expect(await minter.tid(137, '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270')).equal(0);
        expect(await minter.tid(43114, '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7')).equal(1);
        expect(await minter.tid(1313161554, '0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d')).equal(2);

        expect(await vault.owner()).equal(deployer.address);
        expect(await vault.admin()).equal(common.admin);
        expect(await vault.strategy()).equal(strategy.address);
        expect(await vault.priceOracle()).equal(priceOracle.address);
        expect(await vault.USDT()).equal(network_.Swap.USDT);
        expect(await vault.profitFeePerc()).equal(2000);

        expect(await strategy.owner()).equal(deployer.address);
        expect(await strategy.treasuryWallet()).equal(common.treasury);
        expect(await strategy.admin()).equal(common.admin);
        expect(await strategy.vault()).equal(vault.address);
        expect(await strategy.priceOracle()).equal(priceOracle.address);
        expect(await strategy.router()).equal(network_.Swap.router);
        expect(await strategy.SWAP_BASE_TOKEN()).equal(network_.Swap.SWAP_BASE_TOKEN);
        expect(await strategy.USDT()).equal(network_.Swap.USDT);
        expect(await strategy.tokens(0)).equal(network_.Swap.WAVAX);
        expect(await strategy.pid(network_.Swap.WAVAX)).equal(0);
        const WAVAXVaultAddr = await strategy.WAVAXVault();

        const WAVAXVault = new ethers.Contract(WAVAXVaultAddr, l2VaultArtifact.abi, a1);
        expect(await WAVAXVault.name()).equal('MWI L2 WAVAX');
        expect(await WAVAXVault.symbol()).equal('mwiL2WAVAX');
        expect(await WAVAXVault.aToken()).equal(network_.Aave3.aAvaWAVAX);
        expect(await WAVAXVault.admin()).equal(common.admin);
        expect(await WAVAXVault.treasuryWallet()).equal(common.treasury);
        expect(await WAVAXVault.yieldFee()).equal(2000);
      });

      it("Should be set by only owner", async () => {
        await expectRevert(priceOracle.setAssetSources([a2.address],[a1.address]), "Ownable: caller is not the owner");

        await expectRevert(bni.setMinter(a2.address), "Ownable: caller is not the owner");
        await expectRevert(bni.mint(a2.address, parseEther('1')), "Mintable: caller is not the minter");

        await expectRevert(minter.setAdmin(a2.address), "Ownable: caller is not the owner");
        await expectRevert(minter.addToken(1, a1.address), "Ownable: caller is not the owner");
        await expectRevert(minter.removeToken(1), "Ownable: caller is not the owner");
        await expectRevert(minter.setTokenCompositionTargetPerc([10000]), "Ownable: caller is not the owner");
        await expectRevert(minter.mint(parseEther('1000'), a1.address, getUsdtAmount('100')), "Only owner or admin");
        await expectRevert(minter.burn(a1.address, getUsdtAmount('100')), "Only owner or admin");

        await expectRevert(vault.setAdmin(a2.address), "Ownable: caller is not the owner");
        await expectRevert(vault.deposit(a1.address, [a2.address], [getUsdtAmount('100')]), "Only owner or admin");
        await expectRevert(vault.withdrawPerc(a1.address, parseEther('0.1')), "Only owner or admin");
        await expectRevert(vault.rebalance(0, parseEther('0.1'), a2.address), "Only owner or admin");
        await expectRevert(vault.emergencyWithdraw(), "Only owner or admin");
        await expectRevert(vault.reinvest([a2.address], [10000]), "Only owner or admin");
        await expectRevert(vault.setProfitFeePerc(1000), "Ownable: caller is not the owner");
        await expectRevert(vault.collectProfitAndUpdateWatermark(), "Only owner or admin");
        await expectRevert(vault.withdrawFees(), "Only owner or admin");

        await expectRevert(strategy.addToken(a1.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.removeToken(1), "Ownable: caller is not the owner");
        await expectRevert(strategy.setTreasuryWallet(a2.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.setAdmin(a2.address), "Ownable: caller is not the owner");
        await expectRevert(strategy.setVault(a2.address), "Ownable: caller is not the owner");
      });

      it("Should be returned with correct default vaule", async () => {
        var avaxAPR = await vault.getAPR();
        var avaxPool = await vault.getAllPoolInUSD();
        expect(avaxAPR).gt(0);
        expect(avaxPool).equal(0);
        expect(await minter.getAPR([avaxPool], [avaxAPR])).equal(0);
        expect(await minter.getPricePerFullShare([avaxPool])).equal(parseEther('1'));

        var ret = await minter.getCurrentTokenCompositionPerc([],[],[])
        var chainIDs = ret[0];
        var tokens = ret[1];
        var pools = ret[2];
        var percentages = ret[3];
        expect(chainIDs.length).equal(3);
        expect(chainIDs[0]).equal(137);
        expect(chainIDs[1]).equal(43114);
        expect(chainIDs[2]).equal(1313161554);
        expect(tokens[0]).equal('0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270');
        expect(tokens[1]).equal('0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7');
        expect(tokens[2]).equal('0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d');
        expect(pools[0]).equal(0);
        expect(pools[1]).equal(0);
        expect(pools[2]).equal(0);
        expect(percentages[0]).equal(4000);
        expect(percentages[1]).equal(4000);
        expect(percentages[2]).equal(2000);

        ret = await vault.getEachPoolInUSD();
        chainIDs = ret[0];
        tokens = ret[1];
        pools = ret[2];
        expect(chainIDs.length).equal(1);
        // expect(chainIDs[0]).equal(137);
        expect(tokens[0]).equal('0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7');
        expect(pools[0]).equal(0);
      });
    });

    describe('Basic function', () => {
      it("Basic Deposit/withdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        const WAVAXVault = new ethers.Contract(await strategy.WAVAXVault(), l2VaultArtifact.abi, a1);
        expect(await WAVAXVault.getAPR()).gt(0);

        var ret = await vault.getEachPoolInUSD();
        var chainIDs = ret[0];
        var tokens = ret[1];
        var pools = ret[2];
        ret = await minter.getDepositTokenComposition(chainIDs, tokens, pools, getUsdtAmount('50000'));
        chainIDs = ret[0];
        tokens = ret[1];
        USDTAmts = ret[2];
        expect(chainIDs.length).equal(3);
        expect(USDTAmts[0]).equal(getUsdtAmount('50000').mul(4).div(10));
        expect(USDTAmts[1]).equal(getUsdtAmount('50000').mul(4).div(10));
        expect(USDTAmts[2]).equal(getUsdtAmount('50000').mul(2).div(10));
        expect(USDTAmts[0].add(USDTAmts[1]).add(USDTAmts[2])).equal(getUsdtAmount('50000'));

        await vault.connect(admin).deposit(a1.address, tokens, USDTAmts);
        expect(await usdt.balanceOf(a1.address)).equal(0);
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(100));
        var avaxAPR = await vault.getAPR();
        var avaxPool = await vault.getAllPoolInUSD();
        var allPool = await minter.getAllPoolInUSD([avaxPool]);
        expect(allPool).closeTo(parseEther('50000'), parseEther('50000').div(100));
        await minter.connect(admin).mint(allPool, a1.address, getUsdtAmount('50000'));
        expect(await bni.balanceOf(a1.address)).closeTo(parseEther('50000'), parseEther('50000').div(100));
        expect(await minter.getPricePerFullShare([avaxPool])).closeTo(parseEther('1'), parseEther('1').div(100));
        expect(await minter.getAPR([avaxPool], [avaxAPR])).gt(0);

        await increaseTime(DAY);
        expect(await WAVAXVault.getPendingRewards()).gt(0);
        await WAVAXVault.connect(admin).yield();

        const share = await bni.balanceOf(a1.address);
        await expectRevert(minter.getWithdrawPerc(a1.address, share.add(1)), "Invalid share amount");
        const sharePerc = await minter.getWithdrawPerc(a1.address, share);
        expect(sharePerc).equal(parseEther('1'));
        await minter.connect(admin).burn(a1.address, share);
        expect(await bni.balanceOf(a1.address)).equal(0);
        expect(await bni.totalSupply()).equal(0);
        await vault.connect(admin).withdrawPerc(a1.address, sharePerc);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(100));
        expect(await vault.getAllPoolInUSD()).equal(0);
      });

      it("Deposit/withdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('10000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('10000'));
        await usdt.transfer(a2.address, getUsdtAmount('10000'));
        await usdt.connect(a2).approve(vault.address, getUsdtAmount('10000'));

        // deposit with a1
        var ret = await vault.getEachPoolInUSD();
        var chainIDs = ret[0];
        var tokens = ret[1];
        var pools = ret[2];
        ret = await minter.getDepositTokenComposition(chainIDs, tokens, pools, getUsdtAmount('10000'));
        chainIDs = ret[0];
        tokens = ret[1];
        USDTAmts = ret[2];

        await vault.connect(admin).deposit(a1.address, tokens, USDTAmts);
        var avaxPool = await vault.getAllPoolInUSD();
        var allPool = await minter.getAllPoolInUSD([avaxPool]);
        await minter.connect(admin).mint(allPool, a1.address, getUsdtAmount('10000'));

        // deposit with a2
        ret = await vault.getEachPoolInUSD();
        chainIDs = ret[0];
        tokens = ret[1];
        pools = ret[2];
        ret = await minter.getDepositTokenComposition([43114], tokens, pools, getUsdtAmount('10000'));
        chainIDs = ret[0];
        tokens = ret[1];
        USDTAmts = ret[2];
        expect(chainIDs.length).equal(3);
        expect(USDTAmts[0]).gt(0);
        expect(USDTAmts[1]).equal(0);
        expect(USDTAmts[2]).gt(0);
        expect(USDTAmts[0].add(USDTAmts[1]).add(USDTAmts[2])).closeTo(getUsdtAmount('10000'), 1);

        await vault.connect(admin).deposit(a2.address, tokens, USDTAmts);
        expect(await usdt.balanceOf(a2.address)).closeTo(parseEther('0'), 1);
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('20000'), parseEther('20000').div(100));
        var avaxPool = await vault.getAllPoolInUSD();
        var allPool = await minter.getAllPoolInUSD([avaxPool]);
        expect(allPool).closeTo(parseEther('20000'), parseEther('20000').div(100));
        await minter.connect(admin).mint(allPool, a2.address, getUsdtAmount('10000'));
        expect(await bni.balanceOf(a2.address)).closeTo(parseEther('10000'), parseEther('10000').div(100));
        expect(await minter.getPricePerFullShare([avaxPool])).closeTo(parseEther('1'), parseEther('1').div(100));

        // withdraw a1
        var share = await bni.balanceOf(a1.address);
        var sharePerc = await minter.getWithdrawPerc(a1.address, share);
        expect(sharePerc).closeTo(parseEther('0.5'), parseEther('0.5').div(100));
        await minter.connect(admin).burn(a1.address, share);
        expect(await bni.balanceOf(a1.address)).equal(0);
        expect(await bni.totalSupply()).closeTo(parseEther('10000'), parseEther('10000').div(100));
        await vault.connect(admin).withdrawPerc(a1.address, sharePerc);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('10000'), getUsdtAmount('10000').div(100));
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('10000'), parseEther('10000').div(100));

        // withdraw a2
        share = await bni.balanceOf(a2.address);
        sharePerc = await minter.getWithdrawPerc(a2.address, share);
        expect(sharePerc).equal(parseEther('1'));
        await minter.connect(admin).burn(a2.address, share);
        expect(await bni.balanceOf(a2.address)).equal(0);
        expect(await bni.totalSupply()).equal(0);
        await vault.connect(admin).withdrawPerc(a2.address, sharePerc);
        expect(await usdt.balanceOf(a2.address)).closeTo(getUsdtAmount('10000'), getUsdtAmount('10000').div(100));
        expect(await vault.getAllPoolInUSD()).equal(0);
      });

      it("emergencyWithdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        var ret = await vault.getEachPoolInUSD();
        var chainIDs = ret[0];
        var tokens = ret[1];
        var pools = ret[2];
        ret = await minter.getDepositTokenComposition(chainIDs, tokens, pools, getUsdtAmount('50000'));
        chainIDs = ret[0];
        tokens = ret[1];
        USDTAmts = ret[2];
        await vault.connect(admin).deposit(a1.address, tokens, USDTAmts);
        var avaxPool = await vault.getAllPoolInUSD();
        var allPool = await minter.getAllPoolInUSD([avaxPool]);
        await minter.connect(admin).mint(allPool, a1.address, getUsdtAmount('50000'));

        await vault.connect(admin).emergencyWithdraw();
        expect(await usdt.balanceOf(vault.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(20));

        ret = await vault.getCurrentCompositionPerc();
        await vault.connect(admin).reinvest(ret[0], ret[1]);
        expect(await usdt.balanceOf(vault.address)).equal(0);
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(50));

        await vault.connect(admin).emergencyWithdraw();

        var share = await bni.balanceOf(a1.address);
        var sharePerc = await minter.getWithdrawPerc(a1.address, share);
        expect(sharePerc).equal(parseEther('1'));
        await minter.connect(admin).burn(a1.address, share);
        expect(await bni.balanceOf(a1.address)).equal(0);
        expect(await bni.totalSupply()).equal(0);
        await vault.connect(admin).withdrawPerc(a1.address, sharePerc);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(50));
        expect(await vault.getAllPoolInUSD()).equal(0);
      });

      it("Rebalance", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        await strategy.connect(deployer).addToken('0xc7198437980c041c805A1EDcbA50c1Ce5db95118');
        await minter.connect(deployer).addToken(43114, '0xc7198437980c041c805A1EDcbA50c1Ce5db95118');
        await expectRevert(minter.connect(deployer).setTokenCompositionTargetPerc([4000,3000,2000]), "Invalid count");
        await expectRevert(minter.connect(deployer).setTokenCompositionTargetPerc([4000,3000,2000,100]), "Invalid parameter");
        await minter.connect(deployer).setTokenCompositionTargetPerc([4000,3000,2000,1000]);
        expect(await minter.chainIDs(3)).equal(43114);
        expect(await minter.tokens(3)).equal('0xc7198437980c041c805A1EDcbA50c1Ce5db95118');
        expect(await minter.targetPercentages(3)).equal(1000);
        expect(await minter.tid(43114, '0xc7198437980c041c805A1EDcbA50c1Ce5db95118')).equal(3);

        var ret = await vault.getEachPoolInUSD();
        var chainIDs = ret[0];
        var tokens = ret[1];
        var pools = ret[2];
        ret = await minter.getDepositTokenComposition(chainIDs, tokens, pools, getUsdtAmount('50000'));
        chainIDs = ret[0];
        tokens = ret[1];
        USDTAmts = ret[2];
        expect(chainIDs.length).equal(4);
        expect(USDTAmts[0]).equal(getUsdtAmount('50000').mul(4).div(10));
        expect(USDTAmts[1]).equal(getUsdtAmount('50000').mul(3).div(10));
        expect(USDTAmts[2]).equal(getUsdtAmount('50000').mul(2).div(10));
        expect(USDTAmts[3]).equal(getUsdtAmount('50000').mul(1).div(10));
        expect(USDTAmts[0].add(USDTAmts[1]).add(USDTAmts[2]).add(USDTAmts[3])).equal(getUsdtAmount('50000'));

        await vault.connect(admin).deposit(a1.address, tokens, USDTAmts);
        expect(await usdt.balanceOf(a1.address)).equal(0);
        expect(await vault.getAllPoolInUSD()).closeTo(parseEther('50000'), parseEther('50000').div(100));
        var avaxPool = await vault.getAllPoolInUSD();
        var allPool = await minter.getAllPoolInUSD([avaxPool]);
        expect(allPool).closeTo(parseEther('50000'), parseEther('50000').div(100));
        await minter.connect(admin).mint(allPool, a1.address, getUsdtAmount('50000'));
        expect(await bni.balanceOf(a1.address)).closeTo(parseEther('50000'), parseEther('50000').div(100));
        expect(await minter.getPricePerFullShare([avaxPool])).closeTo(parseEther('1'), parseEther('1').div(100));

        var tokenPerc = await vault.getCurrentCompositionPerc();
        expect(tokenPerc[0][0]).equal('0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7');
        expect(tokenPerc[0][1]).equal('0xc7198437980c041c805A1EDcbA50c1Ce5db95118');
        expect(tokenPerc[1][0].toNumber()).closeTo(9000, 9000/100);
        expect(tokenPerc[1][1].toNumber()).closeTo(1000, 1000/100);

        await expectRevert(strategy.connect(deployer).removeToken(2), "Invalid pid")
        await expectRevert(strategy.connect(deployer).removeToken(1), "Pool is not empty")

        await vault.connect(admin).rebalance(1, parseEther('1'), '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7');
        tokenPerc = await vault.getCurrentCompositionPerc();
        expect(tokenPerc[0][0]).equal('0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7');
        expect(tokenPerc[0][1]).equal('0xc7198437980c041c805A1EDcbA50c1Ce5db95118');
        expect(tokenPerc[1][0].toNumber()).equal(10000);
        expect(tokenPerc[1][1].toNumber()).equal(0);

        await strategy.connect(deployer).removeToken(1);
        await minter.connect(deployer).removeToken(3);
        await minter.connect(deployer).setTokenCompositionTargetPerc([4000,4000,2000]);

        var share = await bni.balanceOf(a1.address);
        var sharePerc = await minter.getWithdrawPerc(a1.address, share);
        await minter.connect(admin).burn(a1.address, share);
        await vault.connect(admin).withdrawPerc(a1.address, sharePerc);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(50));
        expect(await vault.getAllPoolInUSD()).equal(0);
      });
    });

});