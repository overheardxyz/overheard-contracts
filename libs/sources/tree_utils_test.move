#[test_only]
module libs::tree_utils_test {
    use std::debug::print;
    use std::vector;
    use sui::bcs::to_bytes;
    use std::hash::sha2_256;
    use sui::address::{to_u256, from_bytes};

    #[test]
    fun sha256_tree_test() {
        let x_1 = x"1a";
        let x_2 = x"1a";
        let arr = vector::empty<vector<u8>>();
        vector::push_back(&mut arr, to_bytes(&x_1));
        vector::push_back(&mut arr, to_bytes(&x_2));
        let res = sha2_256(to_bytes(&arr));
        print(&res);
        print(&to_u256(from_bytes(res)));
    }
}
