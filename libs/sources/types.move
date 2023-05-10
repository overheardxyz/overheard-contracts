module libs::types {
    use std::string;

    struct EncodedAsset has store {
        encoded_asset_addr: u256,
        encoded_asset_id: u256,
    }

    struct StealthAddress has store {
        h1_x: u256,
        h1_y: u256,
        h2_x: u256,
        h2_y: u256,
    }

    struct EncryptedNote has store {
        owner: StealthAddress,
        encapped_key: u256,
        encrypted_nonce: u256,
        encrypted_value: u256,
    }

    struct JoinSplit has store {
        commitment_tree_root: u256,
        nullifier_A: u256,
        nullifier_B: u256,
        newNote_A_commitment: u256,
        newNote_B_commitment: u256,
        enc_sender_canon_addr_C1X: u256,
        enc_sender_canon_addr_C2X: u256,
        proof: vector<u256>,
        encoded_asset: EncodedAsset,
        public_spend: u256,
        newNote_A_encrypted: EncryptedNote,
        newNote_B_encrypted: EncryptedNote,
    }

    struct EncodedNote has store {
        owner_H1: u256,
        owner_H2: u256,
        nonce: u256,
        encoded_asset_addr: u256,
        encoded_asset_id: u256,
        value: u256,
    }

    struct DepositRequest has store {
        spender: address,
        encoded_asset: EncodedAsset,
        value: u256,
        deposit_addr: StealthAddress,
        nonce: u256,
        gas_compensation: u256,
    }

    struct Action has store {
        contract_address: address,
        encoded_function: vector<u8>,
    }

    struct Operation has store {
        join_splits: vector<JoinSplit>,
        refund_addr: StealthAddress,
        encoded_refund_assets: vector<EncodedAsset>,
        actions: vector<Action>,
        encoded_gas_asset: EncodedAsset,
        execution_gas_limit: u256,
        max_num_refunds: u256,
        gas_price: u256,
        chain_id: u256,
        deadline: u256,
        atomic_actions: bool,
    }

    struct OperationResult has store {
        opProcessed: bool,
        assetsUnwrapped: bool,
        failureReason: string::String,
        callSuccesses: bool,
        callResults: vector<u8>,
        verificationGas: u256,
        executionGas: u256,
        numRefunds: u256,
    }

    struct Bundle has store {
        operations: vector<Operation>,
    }
}
