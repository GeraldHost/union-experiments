%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin 
from starkware.cairo.common.math import assert_nn, assert_le

#-------------------------------------------------------------
# Types 
#-------------------------------------------------------------

struct Staker:
    member staker: felt
    # amount staked
    member staked: felt
    # amount borrowed
    member outstanding: felt
    # number of vouches given
    member vouchesGiven: felt
    # number of vouches recieved
    member vouchesRecieved: felt
end

struct Vouch:
    member staker: felt
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

@external
func stake{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(staker: felt, amount: felt):
    let (current_staker) = stakers.read(staker)

    let new_staker = Staker(
        staker=current_staker.staker,
        staked=current_staker.staked + amount,
        outstanding=current_staker.outstanding,
        vouchesGiven=current_staker.vouchesGiven,
        vouchesRecieved=current_staker.vouchesRecieved
    )

    stakers.write(staker, new_staker)
    return ()
end

@external
func unstake{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(staker: felt, amount: felt):
    let (current_staker) = stakers.read(staker)

    assert_nn(current_staker.staked - amount)

    let new_staker = Staker(
        staker=current_staker.staker,
        staked=current_staker.staked - amount,
        outstanding=current_staker.outstanding,
        vouchesGiven=current_staker.vouchesGiven,
        vouchesRecieved=current_staker.vouchesRecieved
    )

    stakers.write(staker, new_staker)
    return ()

end

@external
func updateVouch{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(staker: felt, borrower: felt, amount: felt):
    let (current_staker) = stakers.read(staker)
    let (current_borrower) = stakers.read(borrower)

    let new_staker = Staker(
        staker=current_staker.staker,
        staked=current_staker.staked,
        outstanding=current_staker.outstanding,
        vouchesGiven=current_staker.vouchesGiven + 1,
        vouchesRecieved=current_staker.vouchesRecieved
    )

    stakers.write(staker, new_staker)

    let new_borrower = Staker(
        staker=current_borrower.staker,
        staked=current_borrower.staked,
        outstanding=current_borrower.outstanding,
        vouchesGiven=current_borrower.vouchesGiven,
        vouchesRecieved=current_borrower.vouchesRecieved + 1
    )

    stakers.write(borrower, new_borrower)

    let vouch = Vouch(staker=staker, amount=amount)

    vouches.write(borrower, current_borrower.vouchesRecieved, vouch)
    return ()
end

@external
func borrow{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(staker: felt, amount: felt):
    alloc_locals

    let (current_staker) = stakers.read(staker)
    let (credit_limit) = _get_credit_limit(current_staker, 0, 0)

    assert_le(amount, credit_limit)
    
    let new_staker = Staker(
        staker=current_staker.staker,
        staked=current_staker.staked,
        outstanding=current_staker.outstanding + amount,
        vouchesGiven=current_staker.vouchesGiven,
        vouchesRecieved=current_staker.vouchesRecieved
    )

    stakers.write(staker, new_staker)
    return ()
end

@external
func repay{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(staker: felt, amount: felt):
    alloc_locals

    let (current_staker) = stakers.read(staker)

    assert_le(amount, current_staker.outstanding)
    
    let new_staker = Staker(
        staker=current_staker.staker,
        staked=current_staker.staked,
        outstanding=current_staker.outstanding - amount,
        vouchesGiven=current_staker.vouchesGiven,
        vouchesRecieved=current_staker.vouchesRecieved
    )

    stakers.write(staker, new_staker)
    return ()
end

#-------------------------------------------------------------
# Internal 
#-------------------------------------------------------------

@view
func _get_credit_limit{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(staker: Staker, index: felt, amount: felt) -> (res: felt):
    alloc_locals

    if index + 1 == staker.vouchesRecieved:
        return (amount)
    end

    let (vouch) = vouches.read(staker.staker, index)
    let (current_staker) = stakers.read(vouch.staker)
    let value = vouch.amount - current_staker.staked

    # TODO: need to also calculate the locked amounts to do this
    # it is going to be cheap to do reads but we need to change
    # updateVouch to also track the other vouch amounts and outsanding

    let (sum_rest) = _get_credit_limit(staker, index + 1, amount + value)
    return (value + sum_rest)
end
