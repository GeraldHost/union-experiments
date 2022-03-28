// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UToken is ERC20("uDAI", "uDAI") {

  /* -------------------------------------------------------------------
    Types 
  ------------------------------------------------------------------- */
  
  struct Vouch {
    address staker;
    uint256 amount;
  }

  struct Staker {
    address staker;
    uint256 stakedAmount;
    uint256 outstanding;
    // members that are vouching for this staker
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

  mapping(address => Staker) public stakers;

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
  
  /// @notice debug for testing
  event Debug(bytes value);

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

  /// @notice Stake token (DAI) to underwrite loans
  /// @dev Staked tokens (DAI) is used to underwrite loan but is not the
  /// capital that is borrowed. Emits `LogStake` event
  /// @param amount Amount of token (DAI) to stake
  function stake(uint256 amount) external {
    Staker storage staker = stakers[msg.sender];
    staker.stakedAmount += amount;

    _processStake(msg.sender, amount);
    emit LogStake(msg.sender, amount);
  }

  /// @notice Unstake tokens (DAI) from contract
  /// @dev Can only unstake tokens that are not currently locked and underwriting
  /// active loans emits `LogUnstake` event
  /// @param amount Amount of token (DAI) to unstake
  function unstake(uint256 amount) external {
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
  function borrow(uint256 amount) external {
    Staker storage borrower = stakers[msg.sender];
    Vouch[] storage vouches = borrower.vouches;

    uint256 remaining = amount;

    VouchInfo[] memory vouchInfo = _getVouchInfo(vouches);

    uint256 c = 0;

    for(uint256 i = 0; i < vouchInfo.length; i++) {
      Vouch storage vouch = vouches[vouchInfo[i].index];

      uint256 borrowing = _min(remaining, vouchInfo[i].borrowAmount);

      stakers[vouch.staker].outstanding += borrowing;

      remaining -= borrowing;
      c++;
      if(remaining <= 0) break;
    }

    emit Debug(abi.encode(c));
    
    require(remaining <= 0, "!remaining");
    _processBorrow(msg.sender, amount);
    emit LogBorrow(msg.sender, amount);
  }

  /// @notice Repay tokens (DAI) to contract
  /// @dev emits `LogRepay` event
  /// @param amount Amount of tokens (DAI) to repay
  function repay(uint256 amount) external {
    Staker storage borrower = stakers[msg.sender];
    Vouch[] storage vouches = borrower.vouches; 

    uint256 remaining = amount;

    VouchInfo[] memory vouchInfo = _getVouchInfo(vouches);

    for(uint256 i = 0; i < vouchInfo.length; i++) {
      Vouch memory vouch = vouches[vouchInfo[i].index];
      Staker storage staker = stakers[vouch.staker];

      uint256 maxRepay = _min(remaining, staker.outstanding);

      if(maxRepay <= 0) continue;

      staker.outstanding -= maxRepay;

      remaining -= maxRepay;
      if(remaining <= 0) break;
    }

    require(remaining <= 0, "!remaining");
    _processRepay(msg.sender, amount);
    emit LogRepay(msg.sender, amount);
  }

  /// @notice Update a vouch for a user
  /// @dev FIXME: for the sake of keeping this as simple as possible we
  /// are going to ignore deplicate vouches and remove vouches etc
  /// in reality you'd also want to tracking a mapping of vouch indexes
  /// so we can update vouches 
  /// @param borrower Borrower to vouch for
  /// @param amount Amount to vouch for borrower
  function updateVouch(address borrower, uint256 amount) external {
    require(borrower != msg.sender, "!self vouch");

    stakers[borrower].vouches.push(Vouch({
      staker: msg.sender,
      amount: amount
    }));
  }

  /* -------------------------------------------------------------------
    View Functions
  ------------------------------------------------------------------- */

  /// @notice View function to get total vouch for a staker
  /// @param who Stakers address
  function totalVouch(address who) external view returns (uint256 total) {
    Staker storage borrower = stakers[who];

    for(uint256 i = 0; i < borrower.vouches.length; i++) {
      Vouch memory vouch = borrower.vouches[i];
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
  
  /// @notice parse Vouch[] to VouchInfo[]
  function _getVouchInfo(Vouch[] memory vouches) private view returns (VouchInfo[] memory) {
    VouchInfo[] memory vouchInfo = new VouchInfo[](vouches.length);

    for(uint256 i = 0; i < vouches.length; i++) {
      Vouch memory vouch = vouches[i];
      Staker memory staker = stakers[vouch.staker];
      uint256 borrowAmount = _max(staker.stakedAmount, vouch.amount) - staker.outstanding;
      vouchInfo[i] = VouchInfo(i, borrowAmount);
    }
    
    return _sortVouchesInfo(vouchInfo);
  }

  /// @notice sort VouchInfo[] max amount first
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
}
