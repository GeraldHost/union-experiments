## Union Experiments

### The problem we need to solve

At the moment there is a limiting factor to the system. In order to borrow
we need to calculate the amount that is available by looking at all the stakers
that are vouching for us and calculate the vouch (staked - locked).

One of the problems is that the system can become locked up in the scenario where we have to calculate the
locked stake of each voucher. We have to impose a limit to prevent this. Currently we have a max vouchers
limit of 25. This is not great.

### Computing it at the time of borrow

Currently we do this. When somebody wants to borrow we loop through all their stakers, then we loop through
all the stakers borrowers to calculate how much of the stakers stake is already locked in order to get the
vouch. vouchAmount = stakedAmount - lockedAmount. Cold access to storage is 2100 gas. So we burn through gas
really quickly when looking up each staker struct which is about ~5 slots. Say we have 25 stakers vouching for
25 other stakers: `2100*5*(25*25)`. On a standard EVM chain this approach will never scale.

## Solutions to Consider

### Updating storage

One approach is to update the state of each staker when you borrow so you track the outstanding amount. The problem with
this is that even if it's (optimistically) a single SSTORE it's 20k gas per staker and then maybe 10k spent
on loading the vouch struct and another 10k loading the staker struct. So you are always going to hit a limit
pretty quick.

### Root storage

This is a similar approach to updating storage. But instead of storing the entire struct you just store the
hash of the struct (bytes32). Then the structs are passed in as calldata. The clients can build these structs
from the events. The benefit of this over "Updating Storage" is that we don't have to pay to load the structs
from storage and the cost to update the staker is a single slot 20k gas. We also don't have to worry about any
DOS attacks because we can never get locked up, We can only end up out of gas if we are borrowing an amount that
means we have to borrow from many stakers (and in this case we can just do multiple borrow transactions).

## Questions

### Sorting vouchers

we need to find a more scalable way to sort vouches, the sorting algo can be made fairly gas effecient which isn't the
end of the world, but the problem comes when trying to get all the vouches and stakers outstanding amount. Even if we
are loading them from calldata you're paying 16 gas/byte. Ideally users should be able to provide a subset of vouches to
reduce the amount of calldata they need to send. But if you don't send the full set you can't sort them by vouch.

This is the real problem we need to solve. How do we make an EVM friendly but fair way of doing consistent lockups.
