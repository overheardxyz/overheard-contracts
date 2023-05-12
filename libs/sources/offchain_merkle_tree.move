module libs::offchain_merkle_tree {
    use libs::queue;

    struct OffchainMerkleTree has store {
        count: u128,
        batch_len: u128,
        root: u256,
        batch: vector<u256>,
        accumulator_queue: queue::Queue,
        //TODO:subtreeUpdateVerifier
    }

    // fun init(ctx: &mut TxContext) {
    //
    // }

    // fun insert_note(self: &mut OffchainMerkleTree,note: EncodedNote) {
    //     let hashed_note =
    // }
}
