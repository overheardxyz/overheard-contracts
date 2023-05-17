import {
    DEFAULT_SECP256K1_DERIVATION_PATH,
    PRIVATE_KEY_SIZE,
    Secp256k1Keypair,
} from "@mysten/sui.js";
import {describe, it, expect} from 'vitest';
import {secp256k1} from '@noble/curves/secp256k1';
import {fromB64, toB64, toHEX} from '@mysten/bcs';
import {sha256} from '@noble/hashes/sha256';
import {SIGNATURE_SCHEME_TO_FLAG} from "@mysten/sui.js/src/cryptography/signature";

const mnemonic = "trash north romance minute bracket blame vague feel poet remove wait around";

describe('secp256k1-keypair', () => {
    it('create keypair and address from mnemonic', () => {
        const keypair = Secp256k1Keypair.deriveKeypair(mnemonic);
        let address = keypair.getPublicKey().toSuiAddress();
        expect(address).toEqual("0x93f30968734f710b9fd193d877ddff24d48bc8ac2568886488c981ab2ca9876d");
    });
    it('verify sig', () => {
        const keypair = Secp256k1Keypair.deriveKeypair(mnemonic);
        const signData = new TextEncoder().encode('Hello, world!');
        const msgHash = sha256(signData);
        const sig = keypair.signData(signData);
        console.log(keypair.getPublicKey().toSuiAddress());
        let tmp = new Uint8Array(34);
        tmp.set([0x01])
        tmp.set(keypair.getPublicKey().toBytes(), 1);
        console.log(toB64(tmp));
        expect(
            secp256k1.verify(
                secp256k1.Signature.fromCompact(sig),
                msgHash,
                keypair.getPublicKey().toBytes(),
            ),
        ).toBeTruthy();
    });
});