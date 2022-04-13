pragma solidity ^0.8.0;

import "ds-test/test.sol";

contract FrozenLookup is DSTest {
  address public constant staker = address(6969696969);

  uint public constant COUNT = 1000;

  struct Vouch {
    address staker;
    uint128 amount;
    uint128 outstanding;
  }

  struct Staker {
    uint32 lastRepayed;
    uint128 stakedAmount;
    uint128 outstanding;
  }

  mapping(address => Vouch[]) public vouchers;

  mapping(address => Staker) public stakers;

  function _u2a(uint u) internal view returns (address) {
      return address(uint160(uint(keccak256(abi.encodePacked(u)))));
  }
  
  function setUp() public {
    for (uint i = 0; i < COUNT; i++) {
      address voucher = _u2a(i);
      vouchers[staker].push(Vouch(voucher, uint128((i+1)*100), uint128((i+1)*50)));
      stakers[voucher] = Staker(0, uint128(100), uint128(100));
    }
  }

  function testCalculateFrozen() public {
    uint len = vouchers[staker].length;
    uint sum;
    for (uint i = 0; i < len; i++) {
      Vouch memory voucher = vouchers[staker][i];
      Staker memory staker = stakers[voucher.staker];
      if(staker.lastRepayed >= 0) {
        sum += voucher.outstanding;
      } 
    }
    emit log_uint(sum);
  }
} 
