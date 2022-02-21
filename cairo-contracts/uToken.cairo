%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin 
from starkware.cairo.common.math import assert_nn

#-------------------------------------------------------------
# Types 
#-------------------------------------------------------------

struct Staker:
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
        staked=current_staker.staked - amount,
        vouchesGiven=current_staker.vouchesGiven,
        vouchesRecieved=current_staker.vouchesRecieved
    )

    stakers.write(staker, new_staker)
    return ()

end

# func vouch(staker: felt, borrower: felt, amount: felt):
# end

# func borrow(staker: felt, amount: felt):
# end

# func repay(staker: felt, amount: felt):
# end
