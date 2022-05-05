// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "./console.sol";
import "../UToken.sol";

contract UTokenTest is DSTest {
  
  UToken public utoken;

  address bob = address(uint160(uint(keccak256(abi.encodePacked("suss")))));

  function setUp() external {
    utoken = new UToken();
    
    for (uint i = 0; i < 100; i++) {
      address voucher = address(uint160(uint(keccak256(abi.encodePacked(i + 100)))));
      utoken.stake(voucher, 1000); 
      utoken.updateVouch(voucher, bob, 10);
    }
  }

  function testBorrow500() external {
    emit log_uint(utoken.totalVouch(bob));
    utoken.borrow(bob, 500);
  }

  function testBorrow1000() external {
    utoken.borrow(bob, 1000);
  }

  function testUpdateTrust() external {
    address voucher = address(9999);
    utoken.updateVouch(voucher, bob, 100);
  }
}
