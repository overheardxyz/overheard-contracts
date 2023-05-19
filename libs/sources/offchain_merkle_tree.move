module libs::offchain_merkle_tree {
    use libs::queue;
    use libs::types::EncodedNote;
    use std::hash::sha2_256;
    use sui::bcs::to_bytes;
    use std::vector;
    use sui::address::{to_u256, from_bytes};
    use libs::queue::{enqueue, create_queue, lenth, dequeue, peek, Queue};
    use sui::tx_context::TxContext;
    use libs::tree_utils::{u256_to_field_elem_limbs, encode_path_and_hash};

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

    //TODO: verify proof
    public fun apply_subtree_update(
        self: &mut OffchainMerkleTree,
        new_root: u256,
        // proof: vector<u256>
    ): vector<u256> {
        let pis = calculate_public_inputs(self, new_root);
        dequeue(&mut self.accumulator_queue);
        self.root = new_root;
        self.count = self.count + BATCH_SIZE;
        return pis
    }

    fun insert_update(self: &mut OffchainMerkleTree, update: vector<u8>) {
        vector::push_back(&mut self.batch, update);
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
        self.batch = vector::empty<vector<u8>>();
    }

    fun compute_accumulator_hash(self: &mut OffchainMerkleTree): u256 {
        assert!(self.batch_len == BATCH_SIZE, EBatchLenNotEqualToBatchSize);
        let accumulator_hash_bytes = sha2_256(to_bytes(&self.batch));
        to_u256(from_bytes(accumulator_hash_bytes))
    }

    fun calculate_public_inputs(
        self: &mut OffchainMerkleTree,
        new_root: u256
    ): vector<u256> {
        let accumulator_hash = peek(&mut self.accumulator_queue);
        let (hi, lo) = u256_to_field_elem_limbs(accumulator_hash);
        let encoded_path_and_hash = encode_path_and_hash(self.count, hi);
        let pis = vector::empty<u256>();
        vector::push_back(&mut pis, self.root);
        vector::push_back(&mut pis, new_root);
        vector::push_back(&mut pis, encoded_path_and_hash);
        vector::push_back(&mut pis, lo);
        return pis
    }

    public fun get_count(self: &mut OffchainMerkleTree): u64 {
        self.count
    }

    public fun get_root(self: &mut OffchainMerkleTree): u256 {
        self.root
    }

    public fun get_queue(self: &mut OffchainMerkleTree): &mut Queue {
        &mut self.accumulator_queue
    }

    public fun get_total_count(self: &mut OffchainMerkleTree): u64 {
        self.count + self.batch_len + BATCH_SIZE * lenth(&mut self.accumulator_queue)
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
