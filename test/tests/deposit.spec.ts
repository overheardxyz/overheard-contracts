import {
    DEFAULT_SECP256K1_DERIVATION_PATH,
    PRIVATE_KEY_SIZE,
    RawSigner,
    TransactionBlock,
    JsonRpcProvider,
    Ed25519Keypair,
    Secp256k1Keypair, localnetConnection,
} from "@mysten/sui.js";
import {describe, it, expect, beforeEach, beforeAll} from 'vitest';
import {secp256k1} from '@noble/curves/secp256k1';
import {fromB64, toB64, toHEX} from '@mysten/bcs';
import {sha256} from '@noble/hashes/sha256';
import {SIGNATURE_SCHEME_TO_FLAG} from "@mysten/sui.js/src/cryptography/signature";

const {execSync} = require('child_process');
const packagePath = "../main_package";

let activeAddrKeystore = "AEJiIzZOjOgc0v82spQbP1NZQjI3SrhubRZf0VMBJMQO";
const raw = fromB64(activeAddrKeystore);
if (raw[0] !== 0 || raw.length !== PRIVATE_KEY_SIZE + 1) {
    throw new Error('invalid key');
}
const keypair = Ed25519Keypair.fromSecretKey(raw.slice(1));
const provider = new JsonRpcProvider(localnetConnection);
const signer = new RawSigner(keypair, provider);

let packageId = "";
let sharedPoolObjectId = "";
let sharedStateObjectId = "";

describe('test deposit funds', () => {
    it('publish package', async () => {
        const {modules, dependencies} = JSON.parse(
            execSync(
                `sui move build --dump-bytecode-as-base64 --with-unpublished-dependencies --path ${packagePath}`,
                {encoding: 'utf-8'},
            ),
        );
        const tx = new TransactionBlock();
        const [upgradeCap] = tx.publish({
            modules,
            dependencies,
        });
        tx.transferObjects([upgradeCap], tx.pure(await signer.getAddress()));
        let result = await signer.signAndExecuteTransactionBlock({
            transactionBlock: tx,
            options: {showObjectChanges: true, showEffects: true, showEvents: true, showInput: true}
        })
        expect(`${JSON.stringify(result.effects.status.status, null, 2)}`).toEqual(`"success"`);
        // @ts-ignore
        packageId = `${JSON.stringify(result.objectChanges.filter(filterPackageId)[0].packageId, null, 2)}`.replace(/\"/g, "");
        // @ts-ignore
        sharedStateObjectId = `${JSON.stringify(result.objectChanges.filter(filterStateId)[0].objectId, null, 2)}`.replace(/\"/g, "");
        // @ts-ignore
        sharedPoolObjectId = `${JSON.stringify(result.objectChanges.filter(filterPoolId)[0].objectId, null, 2)}`.replace(/\"/g, "");
        console.log(`packageId = ${packageId}, StateObjectId = ${sharedStateObjectId}, sharedPoolObjectId = ${sharedPoolObjectId}`);
    })
    it('initiate deposit', async () => {
        let tx = new TransactionBlock();
        const [coin] = tx.splitCoins(tx.gas, [tx.pure(10000)]);
        tx.moveCall({
            target: `${packageId}::deposit_manager::instantiate_multi_deposit`,
            arguments: [
                tx.object(sharedPoolObjectId),
                tx.object(sharedStateObjectId),
                coin,
                tx.pure([1000]),
                tx.pure(0x1),
                tx.pure(0x1),
                tx.pure(0x1),
                tx.pure(0x1)
            ],
        });
        tx.transferObjects([coin], tx.pure(keypair.getPublicKey().toSuiAddress()));
        tx.setGasBudget(80000000);
        let resultOfExec = await signer.signAndExecuteTransactionBlock({
            transactionBlock:
            tx, options: {showObjectChanges: true, showEffects: true, showEvents: true, showInput: true}
        })
        expect(`${JSON.stringify(resultOfExec.effects.status.status, null, 2)}`).toEqual(`"success"`);
        console.log(`${JSON.stringify(resultOfExec.effects.status.status, null, 2)}`);
    });
    it('complete deposit', async () => {
        let tx = new TransactionBlock();
        tx.moveCall({
            target: `${packageId}::deposit_manager::complete_deposit`,
            arguments: [
                tx.object(sharedStateObjectId),
                tx.pure(keypair.getPublicKey().toSuiAddress()),
                tx.pure(1000),
                tx.pure(0x1),
                tx.pure(0x1),
                tx.pure(0x1),
                tx.pure(0x1),
                tx.pure(0),
                tx.pure(9000)
            ],
        });
        tx.setGasBudget(80000000);
        let resultOfExec = await signer.signAndExecuteTransactionBlock({
            transactionBlock:
            tx, options: {showObjectChanges: true, showEffects: true, showEvents: true, showInput: true}
        })
        console.log(`${JSON.stringify(resultOfExec.effects.status.status, null, 2)}`);
        expect(`${JSON.stringify(resultOfExec.effects.status.status, null, 2)}`).toEqual(`"success"`);
    });
});

function filterPackageId(element, index, array) {
    return element.type == "published";
}

function filterStateId(element, index, array) {
    if (element.type == "created") {
        let ot: string = element.objectType;
        return ot.includes("deposit_manager::State");
    }
    return false;
}

function filterPoolId(element, index, array) {
    if (element.type == "created") {
        let ot: string = element.objectType;
        return ot.includes("deposit_manager::Pool");
    }
    return false;
}
