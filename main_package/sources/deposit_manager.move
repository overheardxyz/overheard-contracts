module main_package::deposit_manager {
    use sui::object::UID;
    use sui::table::Table;
    use sui::coin::Coin;
    use sui::sui::SUI ;
    use sui::tx_context::TxContext;
    use sui::balance::Balance;
    use sui::transfer;
    use sui::object;
    use sui::balance;
    use sui::coin;
    use std::vector::length;
    use std::vector;
    use sui::tx_context;
    use libs::types::{StealthAddress, create_stealth_addr, create_deposit_request};
    use sui::table;
    use sui::bcs::to_bytes;
    use libs::offchain_merkle_tree::{OffchainMerkleTree, create_tree};
    use main_package::teller;

    const EInsufficientCoin: u64 = 0;
    const ECompSplit: u64 = 1;
    const ESpender: u64 = 2;
    const EDepositNotExist: u64 = 3;
    const EDepositState: u64 = 4;
    const EAdminPermission: u64 = 5;

    struct State has key {
        id: UID,
        nonce: u64,
        admin: address,
        outstanding_deposit_hashes: Table<vector<u8>, bool>,
        screener: Table<address,bool>,
        global_note_commitment_tree: OffchainMerkleTree
    }

    struct Pool has key {
        id: UID,
        balance: Balance<SUI>
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(Pool {
            id: object::new(ctx),
            balance: balance::zero()
        });
        let tree = create_tree(ctx);
        transfer::share_object(State {
            id: object::new(ctx),
            nonce: 0,
            admin: tx_context::sender(ctx),
            outstanding_deposit_hashes: table::new(ctx),
            screener: table::new(ctx),
            global_note_commitment_tree: tree
        })
    }

    public entry fun setScreenerPermission(
        state: &mut State,
        screener: address,
        permission: bool,
        ctx: &mut TxContext
    ){
        assert!(state.admin == tx_context::sender(ctx),EAdminPermission);
        if (table::contains(&state.screener,screener)) {
            *table::borrow_mut(&mut state.screener,screener) = permission;
        } else {
            table::add(&mut state.screener,screener,permission);
        }
        // TODO:emit events
    }

    public entry fun instantiate_multi_deposit(
        pool: &mut Pool,
        state: &mut State,
        payment: &mut Coin<SUI>,
        values: vector<u64>,
        h1_x: u256,
        h1_y: u256,
        h2_x: u256,
        h2_y: u256,
        ctx: &mut TxContext
    ) {
        assert!(coin::value(payment) > sum(values), EInsufficientCoin);
        let gas_compensation = coin::value(payment) - sum(values);
        assert!(gas_compensation % length(&values) == 0, ECompSplit);
        let gas_compensation_per_deposit = gas_compensation / length(&values);
        let i: u64 = 0;
        let deposit_addr = create_stealth_addr(h1_x, h1_y, h2_x, h2_y);
        loop {
            if (i < length(&values)) {
                let deposit_request_hash = hash_deposit_request(
                    tx_context::sender(ctx),
                    *vector::borrow(&values, i),
                    copy deposit_addr,
                    state.nonce + i,
                    gas_compensation_per_deposit
                );
                table::add(&mut state.outstanding_deposit_hashes, deposit_request_hash, true);
                //TODO:emit events
                i = i + 1 ;
            } else {
                break
            }
        };
        state.nonce = state.nonce + length(&values);
        // transfer coin to pool
        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, sum(values));
        balance::join(&mut pool.balance, paid);

        //TODO: compensations to screener,current to sender
        let rest_value = balance::value(coin_balance);
        let rest_coin = coin::take(coin_balance, rest_value, ctx);
        transfer::public_transfer(rest_coin, tx_context::sender(ctx));
        // //Test take coin from pool
        // let test_coin = coin::take(&mut pool.balance,10000,ctx);
        // transfer::public_transfer(test_coin,tx_context::sender(ctx));
    }

    public entry fun complete_deposit(
        // pool: &mut Pool,
        state: &mut State,
        spender: address,
        value: u64,
        h1_x: u256,
        h1_y: u256,
        h2_x: u256,
        h2_y: u256,
        nonce: u64,
        gas_compensation: u64,
        // signature: vector<u8>,
        // ctx: &mut TxContext
    ) {
        //TODO:Recover and check screener signature

        let deposit_addr = create_stealth_addr(h1_x, h1_y, h2_x, h2_y);
        let deposit_request_hash = hash_deposit_request(spender, value, deposit_addr, nonce, gas_compensation);
        assert!(table::contains(&state.outstanding_deposit_hashes, deposit_request_hash), EDepositNotExist);
        assert!(*table::borrow(&state.outstanding_deposit_hashes, deposit_request_hash) == true, EDepositState);

        *table::borrow_mut(&mut state.outstanding_deposit_hashes, deposit_request_hash) = false;
        let tree = get_global_tree(state);
        let req = create_deposit_request(spender, value, deposit_addr, nonce, gas_compensation);
        teller::deposit_funds(tree, req);


        //TODO:compute gas fee and pay gas compensation.

        //TODO:emit events
    }

    public entry fun retrieve_deposit(
        pool: &mut Pool,
        state: &mut State,
        spender: address,
        value: u64,
        h1_x: u256,
        h1_y: u256,
        h2_x: u256,
        h2_y: u256,
        nonce: u64,
        gas_compensation: u64,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == spender, ESpender);
        let deposit_addr = create_stealth_addr(h1_x, h1_y, h2_x, h2_y);
        let deposit_request_hash = hash_deposit_request(spender, value, deposit_addr, nonce, gas_compensation);
        assert!(table::contains(&state.outstanding_deposit_hashes, deposit_request_hash), EDepositNotExist);

        *table::borrow_mut(&mut state.outstanding_deposit_hashes, deposit_request_hash) = false;
        let retrieve_coin = coin::take(&mut pool.balance, value, ctx);
        transfer::public_transfer(retrieve_coin, tx_context::sender(ctx));
        //TODO:should send back gas compensation
        //TODO:emit events
    }

    fun sum(items: vector<u64>): u64 {
        let sum: u64 = 0;
        let i = 0;
        loop {
            if (i < length(&items)) {
                let item = *vector::borrow(&items, i);
                sum = sum + item;
                i = i + 1;
            } else {
                break
            }
        };
        sum
    }

    fun hash_deposit_request(
        spender: address,
        value: u64,
        deposit_addr: StealthAddress,
        nonce: u64,
        gas_compensation: u64,
    ): vector<u8> {
        let deposit_request_bytes: &mut vector<u8> = &mut vector::empty<u8>();
        vector::append(deposit_request_bytes, to_bytes(&spender));
        vector::append(deposit_request_bytes, to_bytes(&value));
        vector::append(deposit_request_bytes, to_bytes(&deposit_addr));
        vector::append(deposit_request_bytes, to_bytes(&nonce));
        vector::append(deposit_request_bytes, to_bytes(&gas_compensation));
        *deposit_request_bytes
    }

    public fun get_global_tree(state: &mut State): &mut OffchainMerkleTree {
        &mut state.global_note_commitment_tree
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
