// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "./console.sol";
import "../UToken.sol";

contract UTokenTest is DSTest {
  
  UToken public utoken;

  function setUp() external {
    utoken = new UToken();

    utoken.stake(1000); 
    
    for (uint i = 0; i < 100; i++) {
      address voucher = address(uint160(uint(keccak256(abi.encodePacked(i + 100)))));
      utoken.updateVouch(voucher, msg.sender, 100);
    }
  }

  function testBorrow500() external {
    utoken.borrow(500);
  }

  function testBorrow1000() external {
    utoken.borrow(1000);
  }

  function testUpdateTrust() external {
    address voucher = address(9999);
    utoken.updateVouch(voucher, msg.sender, 100);
  }
}
