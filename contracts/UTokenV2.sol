// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UTokenV2 {

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

  IERC20 public token;

  mapping(address => Staker) public stakers;

  mapping(address => Vouch[]) public vouchers;

  /* -------------------------------------------------------------------
    Events 
  ------------------------------------------------------------------- */

  /// @notice Event emitted when user stakes
  /// @param sender The sender who staked
  /// @param amount Amount of tokens (DAI) staked
  event LogStake(address sender, uint256 amount);

  /// @notice Event emitted when user unstakes
  /// @param sender The sender who unstaked
  /// @param amount Amount of tokens (DAI) unstaked
  event LogUnstake(address sender, uint256 amount);

  /// @notice Event emitted when user borrows
  /// @param sender Sender who borrows
  /// @param amount Amount borrowed
  event LogBorrow(address sender, uint256 amount);

  /// @notice Event emitted when user repays
  /// @param sender Sender who repaid
  /// @param amount Amount repaid
  event LogRepay(address sender, uint256 amount);

  /* -------------------------------------------------------------------
    Constructooor 
  ------------------------------------------------------------------- */
  
  constructor(IERC20 _token) {
    token = _token;
  }

  /* -------------------------------------------------------------------
    Core Functions
  ------------------------------------------------------------------- */

  /// @notice Stake token (DAI) to underwrite loans
  /// @dev Staked tokens (DAI) is used to underwrite loan but is not the
  /// capital that is borrowed. Emits `LogStake` event
  /// @param amount Amount of token (DAI) to stake
  function stake(uint256 amount) public {
    Staker storage staker = stakers[msg.sender];
    staker.stakedAmount += amount;

    _processStake(msg.sender, amount);
    emit LogStake(msg.sender, amount);
  }

  /// @notice Unstake tokens (DAI) from contract
  /// @dev Can only unstake tokens that are not currently locked and underwriting
  /// active loans emits `LogUnstake` event
  /// @param amount Amount of token (DAI) to unstake
  function unstake(uint256 amount) public {
    Staker storage staker = stakers[msg.sender];
    uint256 unstakeable = staker.stakedAmount - staker.outstanding;
    require(unstakeable >= amount, "!liquid");
    staker.stakedAmount -= amount;

    _processUnstake(msg.sender, amount);
    emit LogUnstake(msg.sender, amount);
  }
  
  /// @notice Borrow tokens (DAI) from contract
  /// @dev emits `LogBorrow` event
  /// @param amount Amount of tokens (DAI) to borrow
  function borrow(uint256 amount) public {
    uint256 remaining = amount;

    for(uint256 i = 0; i < vouchers[msg.sender].length; i++) {
      Vouch storage vouch = vouchers[msg.sender][i];
      
      uint borrowAmount = vouch.amount - vouch.outstanding;
      if(borrowAmount <= 0) continue;

      uint256 borrowing = _min(remaining, borrowAmount);

      stakers[vouch.staker].outstanding += borrowing;
      vouch.outstanding += borrowing;

      remaining -= borrowing;
      if(remaining <= 0) break;
    }

    require(remaining <= 0, "!remaining");
    _processBorrow(msg.sender, amount);
    emit LogBorrow(msg.sender, amount);
  }

  /// @notice Update a vouch for a user
  function updateVouch(address borrower, uint256 amount) public {
    require(borrower != msg.sender, "!self vouch");
    vouchers[msg.sender].push(Vouch(msg.sender, amount, 0));
  }

  /* -------------------------------------------------------------------
    View Functions
  ------------------------------------------------------------------- */

  /// @notice View function to get total vouch for a staker
  function totalVouch(address who) public view returns (uint256 total) {
    for(uint256 i = 0; i < vouchers[who].length; i++) {
      Vouch memory vouch = vouchers[who][i];
      Staker memory staker = stakers[vouch.staker];
      total += _max(staker.stakedAmount, vouch.amount) - staker.outstanding;
    }
  }

  /* -------------------------------------------------------------------
    Internal Functions 
  ------------------------------------------------------------------- */
  
  /// @dev Get min of two numbers
  function _min(uint256 a, uint256 b) private pure returns (uint256) {
    if(a < b) return a;
    return b;
  }

  /// @dev Get max of two numbers
  function _max(uint256 a, uint256 b) private pure returns (uint256) {
    if(a > b) return a;
    return b;
  }
  
  /// @dev Send tokens from contract to borrower
  function _processBorrow(address borrower, uint256 amount) private {
    token.transfer(borrower, amount);
  }

  /// @dev Send tokens from borrower to contract
  function _processRepay(address borrower, uint256 amount) private {
    token.transferFrom(borrower, address(this), amount);
  }
  
  /// @dev Send tokens from staker to contract
  /// @param staker Staker to recieve tokens from
  /// @param amount Amount of tokens to send
  function _processStake(address staker, uint256 amount) private {
    token.transferFrom(staker, address(this), amount);
  }

  /// @dev Send tokens from contract to staker 
  /// @param staker Staker to send tokens to
  /// @param amount Amount of tokens to send
  function _processUnstake(address staker, uint256 amount) private {
    token.transfer(staker, amount);
  }
}
