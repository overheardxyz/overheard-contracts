module libs::tree_utils {
    use libs::types::EncodedNote;
    use sui::bcs::to_bytes;
    use std::hash;

    const DEPTH: u8 = 16;
    const BATCH_SIZE: u256 = 16;
    const BATCH_SUBTREE_DEPTH: u8 = 2;
    const EMPTY_TREE_ROOT: u256 = 9533201250583817767896570092866591469094150406835227552485691564931228351592;

    const ESubtreeIdx: u64 = 1;

    fun encode_path_and_hash(subtree_idx: u256,accumulator_hash_hi: u256): u256 {
        assert!(subtree_idx % BATCH_SIZE == 0,ESubtreeIdx);
        let encoded_path_and_hash: u256 = subtree_idx >> (2 * BATCH_SUBTREE_DEPTH);
        encoded_path_and_hash = encoded_path_and_hash | (accumulator_hash_hi << (2 * (DEPTH - BATCH_SUBTREE_DEPTH)));
        return encoded_path_and_hash
    }

    public fun sha256Note(note: EncodedNote): vector<u8> {
        let note_bytes = to_bytes(&note);
        hash::sha2_256(note_bytes)
    }
}