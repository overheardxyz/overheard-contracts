module libs::offchain_merkle_tree {
    use libs::queue;
    use libs::types::EncodedNote;
    use std::hash::sha2_256;
    use sui::bcs::to_bytes;
    use std::vector;
    use sui::address::{to_u256, from_bytes};
    use libs::queue::{enqueue, create_queue, lenth};
    use sui::tx_context::TxContext;

    const DEPTH: u8 = 16;
    const BATCH_SIZE: u64 = 16;
    const BATCH_SUBTREE_DEPTH: u8 = 2;
    const EMPTY_TREE_ROOT: u256 = 9533201250583817767896570092866591469094150406835227552485691564931228351592;

    const EBatchLenNotEqualToBatchSize: u64 = 1;

    struct OffchainMerkleTree has store {
        count: u64,
        batch_len: u64,
        root: u256,
        batch: vector<vector<u8>>,
        accumulator_queue: queue::Queue,
        //TODO:subtreeUpdateVerifier
    }

    public fun insert_note(self: &mut OffchainMerkleTree, note: EncodedNote) {
        let hashed_note = sha2_256(to_bytes(&note));
        insert_update(self, hashed_note);
    }

    fun insert_update(self: &mut OffchainMerkleTree, update: vector<u8>) {
        *vector::borrow_mut(&mut self.batch, self.batch_len) = update;
        self.batch_len = self.batch_len + 1;

        if (self.batch_len == BATCH_SIZE) {
            accumulate(self);
        }
    }

    fun accumulate(self: &mut OffchainMerkleTree) {
        assert!(self.batch_len == BATCH_SIZE, EBatchLenNotEqualToBatchSize);
        let accumulator_hash = compute_accumulator_hash(self);
        enqueue(&mut self.accumulator_queue, accumulator_hash);
        self.batch_len = 0;
    }

    fun compute_accumulator_hash(self: &mut OffchainMerkleTree): u256 {
        assert!(self.batch_len == BATCH_SIZE, EBatchLenNotEqualToBatchSize);
        let accumulator_hash_bytes = sha2_256(to_bytes(&self.batch));
        to_u256(from_bytes(accumulator_hash_bytes))
    }

    public fun get_count(self: &mut OffchainMerkleTree):u64 {
        self.count
    }

    public fun get_root(self: &mut OffchainMerkleTree):u256 {
        self.root
    }

    public fun get_total_count(self: &mut OffchainMerkleTree): u64 {
        self.count + self.batch_len + BATCH_SIZE*lenth(&mut self.accumulator_queue)
    }

    public fun create_tree(ctx: &mut TxContext): OffchainMerkleTree {
        OffchainMerkleTree {
            root: EMPTY_TREE_ROOT,
            count: 0,
            batch_len: 0,
            batch: vector::empty<vector<u8>>(),
            accumulator_queue: create_queue(ctx)
        }
    }
}
