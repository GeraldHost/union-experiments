At the moment there is a limiting factor to the system. In order to borrow
we need to calculate the amount that is available by looking at all the stakers
that are vouching for us and calculate the vouch (staked - locked).

## (1) Updating storage

One approach is to update the state of each staker when you borrow. The problem with
this is that even if it's (optimistically) a single SSTORE it's 20k gas per staker. So you
are always going to hit a limit of say ~500 stakers. This is fine for single entities but
if I am a contract and I want to vouch for 1000s of people then this will not be possible

## (2) Computing it at the time of borrow

Instead of updating the state of each stakers locked amount when we borrow we can just calculate
it each time. However to do this we end up with an exponential problem because to get the locked stake
of each staker vouching for us we need to check all of their borrowers to see how much is being borrowed.
This approach saves gas on the state update side, but it uses hella gas to actually calculate. Which makes
this approach even more limiting that (1)

## DOS

One of the worries is that the system can become locked up in the scenario where we have to calculate the
locked stake of each voucher so we have to impose a limit to prevent this if we take the approach of (2).
This is super bad.

If we are updating the state as we go as in the case of (1) We don't need to worry about a DOS because
the gas limit is just limiting in the context of a single borrow, so if you run out of gas you can just
reduce the amount you want to borrow and therefor reduce the number of staker states you need to update.
This is obviously still not ideal.

## Solution

(2) is unscallable on an EVM chain, although on a zk chain it's potentially better because computation is
much much cheaper

(1) is scalable on an EVM chain. Even though you can have a situation where the borrow runs out of
gas because you are trying to borrow from too many accounts which will cause a min of 20k gas per update,
You only need to protect the sorting function from being DOSd. (if we decide to keep the sort)

There would also likely be more chance to make the sorts cheaper compared to trying to make less storage
writes.
