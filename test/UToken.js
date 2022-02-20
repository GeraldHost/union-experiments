const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther, formatEther } = require("ethers/lib/utils");

const debug = false;

describe("UToken", function () {
  let accounts;
  let fauxToken;
  let uFauxToken;
  let deployer;
  let deployerAddress;

  before(async () => {
    const allAccounts = await ethers.getSigners();

    deployer = allAccounts[0];
    deployerAddress = await deployer.getAddress();
    console.log("deployer:", deployerAddress);

    accounts = allAccounts.slice(1, 26);

    console.log("Accounts: ", accounts.length);

    // 1. deploy FauxToken
    // 2. deploy UToken
    // 3. send FauxToken to users
    const initialMint = parseEther("1000000000");
    console.log("initial mint:", initialMint.toString());
    const FauxToken = await ethers.getContractFactory("FauxToken");
    fauxToken = await FauxToken.deploy(initialMint.toString());
    console.log("fauxToken deployed:", fauxToken.address);

    const UToken = await ethers.getContractFactory("UToken");
    uFauxToken = await UToken.deploy(fauxToken.address);
    console.log("uFauxToken deployed:", uFauxToken.address);

    for (const account of accounts) {
      const accountAddress = await account.getAddress();
      await fauxToken
        .connect(deployer)
        .transfer(accountAddress, parseEther("100"));
      const balance = await fauxToken.balanceOf(accountAddress);
      debug &&
        console.log(
          `Account ${accountAddress} has ${formatEther(balance)} tokens`
        );
    }
  });

  it("happy path: stake", async () => {
    let stakeTotalGasCost = 0;

    for (const account of accounts) {
      const accountAddress = await account.getAddress();
      const balance = await fauxToken.balanceOf(accountAddress);
      await fauxToken.connect(account).approve(uFauxToken.address, balance);
      const tx = await uFauxToken.connect(account).stake(balance);
      const resp = await tx.wait();
      stakeTotalGasCost += Number(resp.cumulativeGasUsed.toString());
    }

    console.log("Average stake gas cost:", stakeTotalGasCost / accounts.length);

    for (const account of accounts) {
      const accountAddress = await account.getAddress();
      const balance = await fauxToken.balanceOf(accountAddress);
      expect(balance.toString()).to.equal("0");
      const staker = await uFauxToken.stakers(accountAddress);
      expect(staker.stakedAmount.toString()).to.equal(
        parseEther("100").toString()
      );
    }
  });

  it("happy path: unstake", async () => {
    let totalUnstakeGasCost = 0;
    const amount = parseEther("1");

    for (const account of accounts) {
      const tx = await uFauxToken.connect(account).unstake(amount.toString());
      const resp = await tx.wait();
      totalUnstakeGasCost += Number(resp.cumulativeGasUsed.toString());
    }

    console.log(
      "Average unstake gas cost:",
      totalUnstakeGasCost / accounts.length
    );

    for (const account of accounts) {
      const accountAddress = await account.getAddress();
      const balance = await fauxToken.balanceOf(accountAddress);
      expect(balance.toString()).to.equal(amount.toString());
      const staker = await uFauxToken.stakers(accountAddress);
      expect(staker.stakedAmount.toString()).to.equal(
        parseEther("99").toString()
      );
    }
  });

  it("happy path: vouches", async () => {
    let totalVouchGasCost = 0;
    let gasCount = 0;

    for (let i = 0; i < accounts.length; i++) {
      const staker = accounts[i];
      const vouchAmount = parseEther(`${i + 1}0`);

      const stakerAddress = await staker.getAddress();

      for (const borrower of accounts) {
        const borrowerAddress = await borrower.getAddress();
        if (borrowerAddress === stakerAddress) {
          // can't vouch for self
          continue;
        }

        const tx = await uFauxToken
          .connect(staker)
          .updateVouch(borrowerAddress, vouchAmount);
        const resp = await tx.wait();

        totalVouchGasCost += Number(resp.cumulativeGasUsed.toString());
        gasCount++;
      }
    }

    console.log("Average updateVouch gas cost:", totalVouchGasCost / gasCount);

    for (const account of accounts) {
      const accountAddress = await account.getAddress();
      const vouch = await uFauxToken.totalVouch(accountAddress);
      const expectedVouch = parseEther("99").mul("9");
      expect(expectedVouch.toString()).to.equal(vouch.toString());
    }
  });

  it("happy path: borrow", async () => {
    const accountAddress = await accounts[0].getAddress();
    const balanceBefore = await fauxToken.balanceOf(accountAddress);
    const tx = await uFauxToken.connect(accounts[0]).borrow(parseEther("10"));
    const resp = await tx.wait();

    console.log(resp.events[0].args);

    console.log("Borrow gas cost:", Number(resp.cumulativeGasUsed.toString()));

    const balanceAfter = await fauxToken.balanceOf(accountAddress);

    expect(balanceAfter.sub(balanceBefore).toString()).to.equal(
      parseEther("10").toString()
    );

    console.log(
      `Borrower ${accountAddress} has borrowed:`,
      formatEther(balanceAfter.sub(balanceBefore).toString())
    );

    // check locks
    for (const account of accounts.slice(1)) {
      const accountAddress = await account.getAddress();
      const staker = await uFauxToken.stakers(accountAddress);
      const locked = staker.outstanding;
      debug &&
        console.log(
          `Staker ${accountAddress} has ${formatEther(
            locked.toString()
          )} locked`
        );
    }
  });

  it("happy path: repay", async () => {
    const accountAddress = await accounts[0].getAddress();
    await fauxToken
      .connect(accounts[0])
      .approve(uFauxToken.address, parseEther("10"));
    const tx = await uFauxToken.connect(accounts[0]).repay(parseEther("10"));
    const resp = await tx.wait();

    console.log("Repay gas cost:", Number(resp.cumulativeGasUsed.toString()));

    const balanceAfter = await fauxToken.balanceOf(accountAddress);

    expect(balanceAfter.toString()).to.equal(parseEther("1").toString());

    // check locks
    for (const account of accounts.slice(1)) {
      const accountAddress = await account.getAddress();
      const staker = await uFauxToken.stakers(accountAddress);
      const locked = staker.outstanding;
      debug &&
        console.log(
          `Staker ${accountAddress} has ${formatEther(
            locked.toString()
          )} locked`
        );
    }
  });
});
