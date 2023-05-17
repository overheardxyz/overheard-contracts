import {
    DEFAULT_SECP256K1_DERIVATION_PATH,
    PRIVATE_KEY_SIZE,
    RawSigner,
    TransactionBlock,
    JsonRpcProvider,
    Ed25519Keypair,
    Secp256k1Keypair, localnetConnection,
} from "@mysten/sui.js";
import {describe, it, expect, beforeEach} from 'vitest';
import {secp256k1} from '@noble/curves/secp256k1';
import {fromB64, toB64, toHEX} from '@mysten/bcs';
import {sha256} from '@noble/hashes/sha256';
import {SIGNATURE_SCHEME_TO_FLAG} from "@mysten/sui.js/src/cryptography/signature";

const { execSync } = require('child_process');
const packagePath = "../main_package"

describe('test deposit funds', () => {
    it('deploy contracts', async () => {
        let activeAddrKeystore = "AEJiIzZOjOgc0v82spQbP1NZQjI3SrhubRZf0VMBJMQO"
        const raw = fromB64(activeAddrKeystore);
        if (raw[0] !== 0 || raw.length !== PRIVATE_KEY_SIZE + 1) {
            throw new Error('invalid key');
        }
        const keypair = Ed25519Keypair.fromSecretKey(raw.slice(1));
        const provider = new JsonRpcProvider(localnetConnection);
        const signer = new RawSigner(keypair, provider);
        const { modules, dependencies } = JSON.parse(
            execSync(
                `sui move build --dump-bytecode-as-base64 --with-unpublished-dependencies --path ${packagePath}`,
                { encoding: 'utf-8' },
            ),
        );
        const tx = new TransactionBlock();
        const [upgradeCap] = tx.publish({
            modules,
            dependencies,
        });
        tx.transferObjects([upgradeCap], tx.pure(await signer.getAddress()));
        const result = await signer.signAndExecuteTransactionBlock({
            transactionBlock: tx,
            options: {showObjectChanges: true, showEffects: true, showEvents: true, showInput: true}
        });
        console.log(`${JSON.stringify(result, null, 2)}`)
    });
});