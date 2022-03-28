// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

contract UTokenV1 is ERC20("uDAI", "uDAI") {

  /* -------------------------------------------------------------------
    Types 
  ------------------------------------------------------------------- */
  
  struct Vouch {
    address addr;
    uint256 amount;
  }

  struct Staker {
    address addr;
    uint256 stakedAmount;
    uint256 outstanding;
    Vouch[] vouches;
  }

  struct VouchInfo {
    // index in the Staker.vouches array
    uint256 index;
    // Staker.stakedAmount - Staker.outstanding
    uint256 borrowAmount;
  }

  /* -------------------------------------------------------------------
    Storage 
  ------------------------------------------------------------------- */

  IERC20 public token;

  mapping(address => bytes32) public roots;

  /* -------------------------------------------------------------------
    Constructooor 
  ------------------------------------------------------------------- */
  
  /// @param _token Underlying token
  constructor(IERC20 _token) {
    token = _token;
  }

  /* -------------------------------------------------------------------
    Core Functions
  ------------------------------------------------------------------- */

  function stake(Staker memory staker, uint amount) external {
    staker.stakedAmount += amount;
    roots[msg.sender] = _root(staker);
  }

  function bytesTest(bytes memory) external {}

  function borrow(
    Staker memory borrower, 
    Staker[] memory stakers, 
    uint amount
  ) external {
    require(roots[borrower.addr] == _root(borrower), "!root");
    require(borrower.vouches.length == stakers.length, "!parity");
    // 1. get the information for each staker
    VouchInfo[] memory info = _getVouchInfo(borrower, stakers);
    // 2. loop through until we have the amount we need
    //    updating the vouchers roots as we go
    uint remaining = amount;
    uint len = info.length; 
    uint i = 0;

    while (remaining > 0) {
      require(i < len, "end");

      Staker memory staker = stakers[info[i].index];
      uint256 borrowing = _min(remaining, info[i].borrowAmount);
      console.log("%s", borrowing);
      staker.outstanding += borrowing;
      // 2. (a) save update staker root
      roots[staker.addr] = _root(staker);
      remaining -= borrowing;
      if(remaining <= 0) break;
      ++i;
    }
    
    require(remaining <= 0, "!remaining");
  }

  function updateTrust(Staker memory borrower, uint amount) external {
    require(roots[borrower.addr] == _root(borrower), "!root");

    uint index = _indexOfVouch(borrower.vouches, msg.sender);
    Vouch[] memory vouches = new Vouch[](borrower.vouches.length + 1);

    for (uint i = 0; i < borrower.vouches.length; i++) {
      vouches[i] = borrower.vouches[i];
    }

    if (index == type(uint256).max) {
      Vouch memory newVouch = Vouch(msg.sender, amount);
      vouches[borrower.vouches.length] = newVouch;
    } else {
      vouches[index].amount += amount;
    }

    borrower.vouches = vouches;
    roots[borrower.addr] = _root(borrower);
  }

  /* -------------------------------------------------------------------
    Internal Functions
  ------------------------------------------------------------------- */

  function _indexOfVouch(Vouch[] memory vouches, address staker) internal returns (uint) {
    uint len = vouches.length;
		for (uint256 i = 0; i < len; i++) {
			if (vouches[i].addr == staker) {
				return i;
			}
		}
		return type(uint256).max;
  }

  function _getVouchInfo(Staker memory borrower, Staker[] memory stakers) private view returns (VouchInfo[] memory) {
    VouchInfo[] memory infoArr = new VouchInfo[](stakers.length);
    for (uint i = 0; i < borrower.vouches.length; i++) {
      Staker memory staker = stakers[i];

      require(staker.addr == borrower.vouches[i].addr, "!staker");
      require(roots[staker.addr] != bytes32(0), "!root");

      uint borrowAmount = staker.stakedAmount - staker.outstanding;
      VouchInfo memory info = VouchInfo(i, borrowAmount);
      infoArr[i] = info;
    }
    return _sortVouchesInfo(infoArr);
  }

  function _sortVouchesInfo(VouchInfo[] memory vouchInfo) private pure returns (VouchInfo[] memory) {
    uint256 length = vouchInfo.length;
    for (uint256 i = 0; i < length; i++) {
      for (uint256 j = i + 1; j < length; j++) {
        if (vouchInfo[i].borrowAmount < vouchInfo[j].borrowAmount) {
          VouchInfo memory temp = vouchInfo[j];
          vouchInfo[j] = vouchInfo[i];
          vouchInfo[i] = temp;
        }
      }
    }
    return vouchInfo; 
  }

  function _root(Staker memory staker) public returns (bytes32) {
		return keccak256(abi.encode(staker));
	}

  function _min(uint256 a, uint256 b) private pure returns (uint256) {
    if(a < b) return a;
    return b;
  }

  function _max(uint256 a, uint256 b) private pure returns (uint256) {
    if(a > b) return a;
    return b;
  }

}
