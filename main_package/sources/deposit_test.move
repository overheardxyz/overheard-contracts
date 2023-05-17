#[test_only]
module main_package::deposit_test {

    use sui::test_scenario;
    use main_package::deposit_manager::{State, Pool, init_for_testing, instantiate_multi_deposit, complete_deposit};
    use std::debug::print;
    use sui::coin;
    use sui::sui::SUI;
    use std::vector;
    use sui::pay;
    use sui::ecdsa_k1;
    use sui::hash::blake2b256;

    #[test]
    fun test_deposit() {
        let user = @0xA;
        let scenario_val = test_scenario::begin(user);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            init_for_testing(ctx);
        };
        test_scenario::next_tx(scenario, user);
        {
            let state_val = test_scenario::take_shared<State>(scenario);
            let pool_val = test_scenario::take_shared<Pool>(scenario);
            let state = &mut state_val;
            let pool = &mut pool_val;
            let ctx = test_scenario::ctx(scenario);
            let test_coin = coin::mint_for_testing<SUI>(10000, ctx);
            let values = vector::empty<u64>();
            vector::push_back(&mut values, 1000);
            instantiate_multi_deposit(pool, state, &mut test_coin, values, 0x1, 0x1, 0x1, 0x1, ctx);
            print(pool);
            print(state);
            test_scenario::return_shared(state_val);
            test_scenario::return_shared(pool_val);
            pay::keep(test_coin, ctx);
        };
        test_scenario::next_tx(scenario, user);
        {
            let state_val = test_scenario::take_shared<State>(scenario);
            let pool_val = test_scenario::take_shared<Pool>(scenario);
            let state = &mut state_val;
            let pool = &mut pool_val;
            // let ctx = test_scenario::ctx(scenario);
            complete_deposit(state, user, 1000, 0x1, 0x1, 0x1, 0x1, 0, 9000);
            print(pool);
            print(state);
            test_scenario::return_shared(state_val);
            test_scenario::return_shared(pool_val);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_recover_addr() {
        let signautre = x"ece1f2f67b9263b7d0c367e9f4974de2b87a290ad40c16e0b51b54184b23ab53006fb6a5d23a3c06c0e57dbb1b98df482809d574d556c10c699cfe5c76bad3f201";
        let msg = b"Hello, world!";
        let pk = ecdsa_k1::secp256k1_ecrecover(&signautre, &msg, 1);
        let tmp = vector::empty<u8>();
        vector::push_back(&mut tmp, 1);
        vector::append(&mut tmp, pk);
        print(&blake2b256(&tmp));
    }
}
