const { ethers } = require("hardhat");

describe("Bytes", function () {
  it("test", async () => {
    const Bytes = await ethers.getContractFactory("Bytes");
    const bytes = await Bytes.deploy();

    for (let i = 0; i < 100; i++) {
      const calldata =
        "0x" +
        Array((i + 1) * 1000)
          .fill(0)
          .map(() => "FF")
          .join("");

      console.log("calldata size:", calldata.length);
      const tx = await bytes.b(calldata, { gasLimit: 30000000 });
      const resp = await tx.wait();
      console.log("gas", resp.cumulativeGasUsed.toString());
    }
  });
});
