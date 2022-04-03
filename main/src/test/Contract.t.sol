// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./console.sol";

contract ContractTest is DSTest {

  /* -------------------------------------------------------------------
    Types 
  ------------------------------------------------------------------- */
  
  struct Vouch {
    address staker;
    uint256 amount;
    uint256 outstanding;
  }

  struct Staker {
    uint256 stakedAmount;
    uint256 outstanding;
  }

  /* -------------------------------------------------------------------
    Storage 
  ------------------------------------------------------------------- */

  mapping(address => Staker) public stakers;

  mapping(address => Vouch[]) public vouchers;

  function borrow(uint256 amount, address borrower_) public {
    uint256 remaining = amount;

    for(uint256 i = 0; i < vouchers[borrower_].length; i++) {
      Vouch storage vouch = vouchers[borrower_][i];
      
      uint borrowAmount = vouch.amount - vouch.outstanding;
      uint256 borrowing = _min(remaining, borrowAmount);

      stakers[vouch.staker].outstanding += borrowing;
      vouch.outstanding += borrowing;

      remaining -= borrowing;
      if(remaining <= 0) break;
    }

    require(remaining <= 0, "!remaining");
  }

  function _min(uint256 a, uint256 b) private pure returns (uint256) {
    if(a < b) return a;
    return b;
  }

  /* -------------------------------------------------------------------
    Test 
  ------------------------------------------------------------------- */

  function setUp() external {
    stakers[address(1)] = Staker(0, 0);
    for (uint i = 0; i < 100; i++) {
      address voucher = address(uint160(uint(keccak256(abi.encodePacked(i + 100)))));
      vouchers[address(1)].push(Vouch(voucher, 100, 0));
    }
  }

  function testBorrow() external {
    borrow(500, address(1));
    assert(true);
  }
}
