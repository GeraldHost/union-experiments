%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin 
from starkware.cairo.common.math import assert_nn

#-------------------------------------------------------------
# Types 
#-------------------------------------------------------------

struct Staker:
    member staker: felt
    # amount staked
    member staked: felt
    # number of vouches given
    member vouchesGiven: felt
    # number of vouches recieved
    member vouchesRecieved: felt
end

struct Vouch:
    member borrower: felt
    member amount: felt
end

#-------------------------------------------------------------
# Storage
#-------------------------------------------------------------

@storage_var
func stakers(staker: felt) -> (res: Staker):
end

@storage_var
func vouches(staker: felt, index: felt) -> (res: Vouch):
end

#-------------------------------------------------------------
# Core 
#-------------------------------------------------------------

func stake{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(staker: felt, amount: felt):
    let (current_staker) = stakers.read(staker)

    let new_staker = Staker(
        staker=current_staker.staker,
        staked=current_staker.staked + amount,
        vouchesGiven=current_staker.vouchesGiven,
        vouchesRecieved=current_staker.vouchesRecieved
    )

    stakers.write(staker, new_staker)
    return ()
end

func unstake{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(staker: felt, amount: felt):
    let (current_staker) = stakers.read(staker)

    assert_nn(current_staker.staked - amount)

    let new_staker = Staker(
        staker=current_staker.staker,
        staked=current_staker.staked - amount,
        vouchesGiven=current_staker.vouchesGiven,
        vouchesRecieved=current_staker.vouchesRecieved
    )

    stakers.write(staker, new_staker)
    return ()

end

func updateVouch{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(staker: felt, borrower: felt, amount: felt):
    let (current_staker) = stakers.read(staker)
    let (current_borrower) = stakers.read(borrower)

    let new_staker = Staker(
        staker=current_staker.staker,
        staked=current_staker.staked,
        vouchesGiven=current_staker.vouchesGiven + 1,
        vouchesRecieved=current_staker.vouchesRecieved
    )

    stakers.write(staker, new_staker)

    let new_borrower = Staker(
        staker=current_borrower.staker,
        staked=current_borrower.staked,
        vouchesGiven=current_borrower.vouchesGiven,
        vouchesRecieved=current_borrower.vouchesRecieved + 1
    )

    stakers.write(borrower, new_borrower)

    let vouch = Vouch(borrower=borrower, amount=amount)

    vouches.write(staker, current_staker.vouchesGiven, vouch)
    return ()
end

# func borrow(staker: felt, amount: felt):
# end

# func repay(staker: felt, amount: felt):
# end

#-------------------------------------------------------------
# Internal 
#-------------------------------------------------------------

func _get_credit_limit{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(staker: Staker, index: felt, amount: felt) -> (res: felt):
    alloc_locals

    if index + 1 == staker.vouchesRecieved:
        return (amount)
    end

    # TODO: lookup staked value of vouch
    # BROKEN
    # We need to store vouches for and vouches given in order to make this
    # credit lookup work, which means lots of storage shit in updateVouch
    # then we should be able to loop to figure out credit limit
    let (vouch) = vouches.read(staker.staker, index)
    let (current_staker) = stakers.read(vouch.staker)
    let value = vouch.amount - current_staker.staked
    let (sum_rest) = _get_credit_limit(staker, index + 1, amount + value)
    return (value + sum_rest)
end
