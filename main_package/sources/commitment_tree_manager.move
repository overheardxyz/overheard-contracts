module main_package::commitment_tree_manager {
    use libs::types::{StealthAddress, get_h1_x, get_h2_x, create_encoded_note};
    use libs::offchain_merkle_tree::{OffchainMerkleTree, get_total_count, insert_note};

    public fun handle_refund_note(merkle: &mut OffchainMerkleTree, refund_addr: StealthAddress, value: u64) {
        let index = get_total_count(merkle);
        let h1_x = get_h1_x(refund_addr);
        let h2_x = get_h2_x(refund_addr);
        let note = create_encoded_note(h1_x, h2_x, index, value);
        insert_note(merkle, note);

        //TODO:emit events
    }
}
