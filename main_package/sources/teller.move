module main_package::teller {
    use sui::object::UID;
    use sui::balance::Balance;
    use sui::sui::SUI;
    use sui::tx_context::TxContext;
    use sui::transfer;
    use sui::object;
    use sui::balance;
    use libs::types::DepositRequest;
    use libs::offchain_merkle_tree::{OffchainMerkleTree};
    use main_package::handler::handle_deposit;

    struct Pool has key {
        id: UID,
        balance: Balance<SUI>
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(Pool {
            id: object::new(ctx),
            balance: balance::zero()
        });
    }

    public fun deposit_funds(merkle_tree: &mut OffchainMerkleTree, deposit_request: DepositRequest) {
        handle_deposit(merkle_tree, deposit_request);
        //TODO: transfer coin to this.
    }
}
