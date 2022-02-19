const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther, formatEther } = require("ethers/lib/utils");

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

    accounts = allAccounts.slice(1, 11);

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
      console.log(
        `Account ${accountAddress} has ${formatEther(balance)} tokens`
      );
    }
  });

  it("happy path: stake", async () => {
    for (const account of accounts) {
      const accountAddress = await account.getAddress();
      const balance = await fauxToken.balanceOf(accountAddress);
      await fauxToken.connect(account).approve(uFauxToken.address, balance);
      await uFauxToken.connect(account).stake(balance);
    }

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
    const amount = parseEther("1");

    for (const account of accounts) {
      await uFauxToken.connect(account).unstake(amount.toString());
    }

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
    const vouchAmount = parseEther("10");

    for (const staker of accounts) {
      const stakerAddress = await staker.getAddress();

      for (const borrower of accounts) {
        const borrowerAddress = await borrower.getAddress();
        if (borrowerAddress === stakerAddress) {
          // can't vouch for self
          continue;
        }

        await uFauxToken
          .connect(staker)
          .updateVouch(borrowerAddress, vouchAmount);
      }
    }

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
    await uFauxToken.connect(accounts[0]).borrow(parseEther("10"));
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
      console.log(
        `Staker ${accountAddress} has ${formatEther(locked.toString())} locked`
      );
    }
  });

  it("happy path: repay", async () => {
    const accountAddress = await accounts[0].getAddress();
    await fauxToken
      .connect(accounts[0])
      .approve(uFauxToken.address, parseEther("10"));
    await uFauxToken.connect(accounts[0]).repay(parseEther("10"));
    const balanceAfter = await fauxToken.balanceOf(accountAddress);

    expect(balanceAfter.toString()).to.equal(parseEther("1").toString());

    // check locks
    for (const account of accounts.slice(1)) {
      const accountAddress = await account.getAddress();
      const staker = await uFauxToken.stakers(accountAddress);
      const locked = staker.outstanding;
      console.log(
        `Staker ${accountAddress} has ${formatEther(locked.toString())} locked`
      );
    }
  });
});
