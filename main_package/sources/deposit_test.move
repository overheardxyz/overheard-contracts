#[test_only]
module main_package::deposit_test {

    use sui::test_scenario;
    use main_package::deposit_manager::{State, Pool, init_for_testing, instantiate_multi_deposit, complete_deposit};
    use std::debug::print;
    use sui::coin;
    use sui::sui::SUI;
    use std::vector;
    use sui::pay;

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
            complete_deposit(state,user,1000,0x1,0x1,0x1,0x1,0,9000);
            print(pool);
            print(state);
            test_scenario::return_shared(state_val);
            test_scenario::return_shared(pool_val);
        };
        test_scenario::end(scenario_val);
    }
}
