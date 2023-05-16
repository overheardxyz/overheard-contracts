module main_package::handler {
    use libs::offchain_merkle_tree::OffchainMerkleTree;
    use libs::types::{DepositRequest, get_deposit_addr, get_deposit_value};
    use main_package::commitment_tree_manager::handle_refund_note;

    public fun handle_deposit(merkle: &mut OffchainMerkleTree, deposit_request: DepositRequest) {
        let deposit_addr = get_deposit_addr(copy deposit_request);
        let deposit_value = get_deposit_value(deposit_request);
        handle_refund_note(merkle, deposit_addr, deposit_value);
        //TODO: emit events
    }
}
