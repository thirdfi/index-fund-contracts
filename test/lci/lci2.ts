const { expect } = require("chai");
const { assert, ethers, deployments } = require("hardhat");
const { expectRevert } = require('@openzeppelin/test-helpers');
const { BigNumber } = ethers;
const parseEther = ethers.utils.parseEther;
import Safe, { SafeFactory, SafeAccountConfig } from '@gnosis.pm/safe-core-sdk'
import { SafeTransactionDataPartial } from '@gnosis.pm/safe-core-sdk-types'
import EthersAdapter from '@gnosis.pm/safe-ethers-lib'
const { increaseTime } = require("../../scripts/utils/ethereum");

const ERC20_ABI = require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable.json").abi;

const { common } = require("../../parameters");

const DAY = 24 * 3600;

function getUsdtAmount(amount) {
  return parseEther(amount);
}

async function createTokenApproveTransaction(safeSdk: Safe, tokenAddress, spenderAddress, amount) {
  const iface = new ethers.utils.Interface(JSON.stringify(ERC20_ABI));
  const data = iface.encodeFunctionData("approve", [spenderAddress, amount]);
  const transaction: SafeTransactionDataPartial = {
    to: tokenAddress, // '0x<address>',
    value: '0', // '<eth_value_in_wei>',
    data: data, // '0x<data>'
  }
  return await safeSdk.createTransaction(transaction)
}

async function createDepositTransaction(safeSdk: Safe, vaultAddress, vaultAbi, amount) {
  const iface = new ethers.utils.Interface(JSON.stringify(vaultAbi));
  const data = iface.encodeFunctionData("deposit", [amount]);
  const transaction: SafeTransactionDataPartial = {
    to: vaultAddress, // '0x<address>',
    value: '0', // '<eth_value_in_wei>',
    data: data, // '0x<data>'
  }
  return await safeSdk.createTransaction(transaction)
}

async function createWithdrawTransaction(safeSdk: Safe, vaultAddress, vaultAbi, shares) {
  const iface = new ethers.utils.Interface(JSON.stringify(vaultAbi));
  const data = iface.encodeFunctionData("withdraw", [shares]);
  const transaction: SafeTransactionDataPartial = {
    to: vaultAddress, // '0x<address>',
    value: '0', // '<eth_value_in_wei>',
    data: data, // '0x<data>'
  }
  return await safeSdk.createTransaction(transaction)
}

async function executeSafeTx(safeSdk: Safe, safeSdk2: Safe, safeTx) {
  const signedSafeTx = await safeSdk2.signTransaction(safeTx);
  const executeTxResponse = await safeSdk.executeTransaction(signedSafeTx);
  await executeTxResponse.transactionResponse?.wait();
}

describe("LCI2", async () => {

    let vault, strategy, usdt;
    let vaultArtifact, strategyArtifact;
    let admin, deployer, a1, a2, accounts;

    before(async () => {
      [deployer, a1, a2, ...accounts] = await ethers.getSigners();
  
      vaultArtifact = await deployments.getArtifact("LCIVault");
      strategyArtifact = await deployments.getArtifact("LCIStrategy");
    });
  
    beforeEach(async () => {
      await deployments.fixture(["hardhat_bsc_lci2"])
  
      vault = new ethers.Contract("0x8FD52c2156a0475e35E0FEf37Fa396611062c9b6", vaultArtifact.abi, a1);
      strategy = new ethers.Contract(await vault.strategy(), strategyArtifact.abi, a1);

      admin = await ethers.getSigner(common.admin);

      usdt = new ethers.Contract('0x55d398326f99059fF775485246999027B3197955', ERC20_ABI, deployer);
    });

    describe('Basic function', () => {
      it("Basic Deposit/withdraw", async () => {
        await usdt.transfer(a1.address, getUsdtAmount('50000'));
        await usdt.connect(a1).approve(vault.address, getUsdtAmount('50000'));

        await vault.deposit(getUsdtAmount('50000'));
        expect(await vault.balanceOf(a1.address)).closeTo(parseEther('50000'), parseEther('50000').div(100));

        await vault.withdraw(await vault.balanceOf(a1.address));
        expect(await vault.balanceOf(a1.address)).equal(0);
        expect(await usdt.balanceOf(a1.address)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(100));
      });
    });

    describe("Test with GnosisSafe", async () => {
      let safeSdk, safeSdk2: Safe;
      let safeAddress;
  
      beforeEach(async () => {
        const ethAdapter = new EthersAdapter({ethers, signer: accounts[0]});
        const safeFactory = await SafeFactory.create({ ethAdapter });
        const owners = [accounts[0].address, accounts[1].address, accounts[2].address];
        const threshold = 2;
        const safeAccountConfig: SafeAccountConfig = {
          owners,
          threshold,
        };
        safeSdk = await safeFactory.deploySafe({ safeAccountConfig })
        safeAddress = safeSdk.getAddress();

        const ethAdapter2 = new EthersAdapter({ethers, signer: accounts[1]});
        safeSdk2 = await safeSdk.connect({ ethAdapter: ethAdapter2, safeAddress })
      });

      it("Basic Deposit/withdraw", async () => {
        await usdt.transfer(safeAddress, getUsdtAmount('50000'));

        var safeTx = await createTokenApproveTransaction(safeSdk, usdt.address, vault.address, getUsdtAmount('50000'));
        await executeSafeTx(safeSdk, safeSdk2, safeTx);
        expect(await usdt.allowance(safeAddress, vault.address)).equal(getUsdtAmount('50000'));

        var safeTx = await createDepositTransaction(safeSdk, vault.address, vaultArtifact.abi, getUsdtAmount('50000'));
        await executeSafeTx(safeSdk, safeSdk2, safeTx);
        expect(await vault.balanceOf(safeAddress)).closeTo(parseEther('50000'), parseEther('50000').div(100));
        expect(await usdt.balanceOf(safeAddress)).equal(0);

        var safeTx = await createWithdrawTransaction(safeSdk, vault.address, vaultArtifact.abi, await vault.balanceOf(safeAddress));
        await executeSafeTx(safeSdk, safeSdk2, safeTx);
        expect(await vault.balanceOf(safeAddress)).equal(0);
        expect(await usdt.balanceOf(safeAddress)).closeTo(getUsdtAmount('50000'), getUsdtAmount('50000').div(100));
      });
    });  

});