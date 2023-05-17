import {
    DEFAULT_SECP256K1_DERIVATION_PATH,
    PRIVATE_KEY_SIZE,
    Secp256k1Keypair,
} from "@mysten/sui.js";
import {describe, it, expect} from 'vitest';
import {secp256k1} from '@noble/curves/secp256k1';
import {fromB64, toB64} from '@mysten/bcs';
import {sha256} from '@noble/hashes/sha256';

describe('secp256k1-keypair', () => {
    it('create keypair from secret key', ()=> {
        const secret_key_base64 = "AF9hftJ26RZUsG692pF3RXOTM6o0Jag83jU9Vz0JvB2E";
        const secret_key = fromB64(secret_key_base64);
        const keypair = Secp256k1Keypair.fromSecretKey(secret_key);
        console.log(keypair);
    });
});