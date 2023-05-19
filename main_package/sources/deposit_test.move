#[test_only]
module main_package::deposit_test {

    use sui::test_scenario;
    use main_package::deposit_manager::{State, Pool, init_for_testing, instantiate_multi_deposit,
    // complete_deposit,
    setScreenerPermission};
    use std::debug::{print};
    use sui::coin;
    use sui::sui::SUI;
    use std::vector;
    use sui::pay;
    use sui::ecdsa_k1;
    use sui::hash::blake2b256;
    use libs::types::{create_stealth_addr, create_deposit_request};
    use sui::address::from_bytes;
    use std::bcs::to_bytes;

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
            let state = &mut state_val;
            let ctx = test_scenario::ctx(scenario);
            let screener_bytes = x"93f30968734f710b9fd193d877ddff24d48bc8ac2568886488c981ab2ca9876d";
            setScreenerPermission(state,from_bytes(screener_bytes),true,ctx);
            print(state);
            test_scenario::return_shared(state_val);
        };
        // test_scenario::next_tx(scenario, user);
        // {
        //     let state_val = test_scenario::take_shared<State>(scenario);
        //     let pool_val = test_scenario::take_shared<Pool>(scenario);
        //     let state = &mut state_val;
        //     let pool = &mut pool_val;
        //     // let ctx = test_scenario::ctx(scenario);
        //     complete_deposit(
        //         state,
        //         user,
        //         1000,
        //         0x1,
        //         0x1,
        //         0x1,
        //         0x1,
        //         0,
        //         9000,
        //         x"06d45ae2fea275e69d9a219bcae991d2f99e5535321c4bb0c8d30c39bf4d290b1e2b2e706ab0366f1fecbba112a0bbb606fb00ddb9941c3ae5eb32c7811691ed00"
        //     );
        //     print(pool);
        //     print(state);
        //     test_scenario::return_shared(state_val);
        //     test_scenario::return_shared(pool_val);
        // };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_recover_addr() {
        let signautre = x"06d45ae2fea275e69d9a219bcae991d2f99e5535321c4bb0c8d30c39bf4d290b1e2b2e706ab0366f1fecbba112a0bbb606fb00ddb9941c3ae5eb32c7811691ed00";
        let spender = x"b4b0f0f1550026c7ddcd64acb31fe0a7dbad95e2fc41ebd9493078d7b334dbaf";
        let stealth_addr = create_stealth_addr(0x1, 0x1, 0x1, 0x1);
        let req = create_deposit_request(from_bytes(spender), 1000, stealth_addr, 0, 9000);
        let msg = to_bytes(&req);
        // let msg = b"Hello, world!";
        let pk = ecdsa_k1::secp256k1_ecrecover(&signautre, &msg, 1);
        let tmp = vector::empty<u8>();
        vector::push_back(&mut tmp, 1);
        vector::append(&mut tmp, pk);
        print(&blake2b256(&tmp));
    }
}
