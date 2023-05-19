#[test_only]
module libs::tree_utils_test {
    use std::debug::print;
    use std::vector;
    use sui::bcs::{to_bytes};
    use std::hash::sha2_256;
    use sui::address::{to_u256, from_bytes};
    use libs::offchain_merkle_tree::{create_tree, get_root, OffchainMerkleTree, insert_note, get_queue};
    use sui::test_scenario;
    use sui::transfer;
    use sui::object::UID;
    use sui::object;
    use libs::types::create_encoded_note;
    use libs::queue::peek;

    struct TestStruct has key {
        id: UID,
        tree: OffchainMerkleTree
    }

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

    #[test]
    fun test_update_tree_and_verify_proof() {
        let user = @0xA;
        let scenario_val = test_scenario::begin(user);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let tree = create_tree(ctx);
            transfer::share_object( TestStruct {
                id: object::new(ctx),
                tree
            });
        };
        test_scenario::next_tx(scenario, user);
        {
            let test_val = test_scenario::take_shared<TestStruct>(scenario);
            let test = &mut test_val;
            let root = get_root(&mut test.tree);
            print(&root);
            test_scenario::return_shared(test_val);
        };
        test_scenario::next_tx(scenario, user);
        {
            let test_val = test_scenario::take_shared<TestStruct>(scenario);
            let test = &mut test_val;
            let i = 0u64;
            loop {
                if (i < 16) {
                    let note = create_encoded_note(0x1,0x1,i,1);
                    insert_note(&mut test.tree,note);
                    i = i+1;
                } else {
                    break
                }
            };
            let acc_hash = peek(get_queue(&mut test.tree));
            print(&acc_hash);
            print(&test.tree);
            test_scenario::return_shared(test_val);
        };
        test_scenario::end(scenario_val);
    }
}
