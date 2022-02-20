const { ethers } = require("hardhat");
const { parseEther, formatEther } = require("ethers/lib/utils");

const debug = true;

async function main() {
  let accounts;
  let fauxToken;
  let uFauxToken;
  let deployer;
  let deployerAddress;

  const allAccounts = await ethers.getSigners();

  deployer = allAccounts[0];
  deployerAddress = await deployer.getAddress();
  console.log("deployer:", deployerAddress);

  accounts = allAccounts.slice(1);

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
    let tx = await fauxToken
      .connect(deployer)
      .transfer(accountAddress, parseEther("100"));
    await tx.wait();
  }

  for (const size of [10, 25, 35, 45, 50]) {
    console.log("testing size:", size);
    console.log("staking");
    for (const account of accounts.slice(0, size)) {
      const accountAddress = await account.getAddress();
      const balance = await fauxToken.balanceOf(accountAddress);
      let tx = await fauxToken
        .connect(account)
        .approve(uFauxToken.address, balance);
      await tx.wait();

      tx = await uFauxToken.connect(account).stake(balance);
      await tx.wait();
    }

    console.log("vouching");

    for (let i = 0; i < size; i++) {
      const staker = accounts[i];
      const vouchAmount = parseEther(`${i + 1}0`);

      const stakerAddress = await staker.getAddress();

      for (const borrower of accounts) {
        const borrowerAddress = await borrower.getAddress();
        if (borrowerAddress === stakerAddress) {
          // can't vouch for self
          continue;
        }

        let tx = await uFauxToken
          .connect(staker)
          .updateVouch(borrowerAddress, vouchAmount);
        await tx.wait();
      }
    }

    console.log("borrow");

    const tx = await uFauxToken.connect(accounts[0]).borrow(parseEther("10"));
    const resp = await tx.wait();

    console.log(resp.events[0].args);

    console.log("Borrow gas cost:", resp.cumulativeGasUsed.toString());
  }
}

main();
