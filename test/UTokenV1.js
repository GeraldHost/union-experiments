const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther, formatEther } = require("ethers/lib/utils");

const debug = true;

const log = (...args) => debug && console.log(...args);

describe("UTokenV1", function () {
  let accounts;
  let fauxToken;
  let uFauxToken;
  let deployer;
  let deployerAddress;

  before(async () => {
    const allAccounts = await ethers.getSigners();

    deployer = allAccounts[0];
    deployerAddress = await deployer.getAddress();
    log("deployer:", deployerAddress);

    accounts = allAccounts.slice(1, 51);

    log("Accounts: ", accounts.length);

    // 1. deploy FauxToken
    // 2. deploy UToken
    // 3. send FauxToken to users
    const initialMint = parseEther("1000000000");
    log("initial mint:", initialMint.toString());
    const FauxToken = await ethers.getContractFactory("FauxToken");
    fauxToken = await FauxToken.deploy(initialMint.toString());
    log("fauxToken deployed:", fauxToken.address);

    const UToken = await ethers.getContractFactory("UTokenV1");
    uFauxToken = await UToken.deploy(fauxToken.address);
    log("uFauxToken deployed:", uFauxToken.address);

    for (const account of accounts) {
      const accountAddress = await account.getAddress();
      await fauxToken
        .connect(deployer)
        .transfer(accountAddress, parseEther("100"));
      await fauxToken.balanceOf(accountAddress);
    }
  });

  const initStake = async (account) => {
    const stakedAmount = parseEther("100");
    const stakerAddress = await account.getAddress();
    const stakerStruct = [stakerAddress, 0, 0, []];
    await uFauxToken.connect(account).stake(stakerStruct, stakedAmount);
    return [stakerAddress, stakedAmount, 0, []];
  };

  describe("for a single staker/borrower", () => {
    let staker;
    let borrower;

    before(() => {
      staker = accounts[0];
      borrower = accounts[1];
    });

    it("stake", async () => {
      await initStake(staker);
      await initStake(borrower);
    });

    it("update trust", async () => {
      const stakedAmount = parseEther("100");
      const borrowerAddress = await borrower.getAddress();
      const trustAmount = parseEther("100");
      const borrowerStruct = [borrowerAddress, stakedAmount, 0, []];
      await uFauxToken.connect(staker).updateTrust(borrowerStruct, trustAmount);
    });

    it("borrow", async () => {
      const stakerAddress = await staker.getAddress();
      const borrowerAddress = await borrower.getAddress();

      const stakedAmount = parseEther("100");
      const stakerStruct = [stakerAddress, stakedAmount, 0, []];
      const stakerStructs = [stakerStruct];

      const trustAmount = parseEther("100");
      const borrowAmount = parseEther("100");
      const vouchStruct = [stakerAddress, trustAmount];
      const borrowerStruct = [borrowerAddress, stakedAmount, 0, [vouchStruct]];

      const tx = await uFauxToken
        .connect(borrower)
        .borrow(borrowerStruct, stakerStructs, borrowAmount);
      const resp = await tx.wait();

      log("gas", resp.cumulativeGasUsed.toString());
    });
  });

  describe("for 10 staker/borrower network", () => {
    let stakers;
    let stakerStructs = [];

    before(() => {
      stakers = accounts.slice(2, 25);
    });

    it("stake", async () => {
      for (const staker of stakers) {
        const struct = await initStake(staker);
        stakerStructs.push(struct);
      }
    });

    it("update trust", async () => {
      const trustAmount = parseEther("100");

      for (let i = 0; i < stakerStructs.length; i++) {
        for (let j = 0; j < stakers.length; j++) {
          const stakerAddress = await stakers[j].getAddress();
          if (stakerAddress !== stakerStructs[i][0]) {
            await uFauxToken
              .connect(stakers[j])
              .updateTrust(stakerStructs[i], trustAmount);
            stakerStructs[i][3].push([stakerAddress, trustAmount]);
          }
        }
      }
    });

    it("borrow", async () => {
      const borrowAmount = parseEther("10");
      const borrowerStruct = stakerStructs[0];
      const stakerStructsInput = stakerStructs.slice(1);

      log("borrower vouches", borrowerStruct[3].length);
      log("staker vouches", stakerStructs.length);

      // TODO: max size of bytes?????
      const calldata = uFauxToken.interface.encodeFunctionData(
        "borrow((address,uint256,uint256,(address,uint256)[]),(address,uint256,uint256,(address,uint256)[])[],uint256)",
        [borrowerStruct, stakerStructsInput, borrowAmount]
      );
      console.log(calldata.length);
      await uFauxToken.bytesTest(calldata);

      const tx = await uFauxToken
        .connect(stakers[0])
        .borrow(borrowerStruct, stakerStructsInput, borrowAmount);
      const resp = await tx.wait();

      log("gas", resp.cumulativeGasUsed.toString());
    });
  });
});
