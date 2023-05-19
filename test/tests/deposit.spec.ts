import {
    DEFAULT_SECP256K1_DERIVATION_PATH,
    PRIVATE_KEY_SIZE,
    RawSigner,
    TransactionBlock,
    JsonRpcProvider,
    Ed25519Keypair,
    Secp256k1Keypair, localnetConnection
} from "@mysten/sui.js";
import {describe, it, expect, beforeEach, beforeAll} from 'vitest';
import {secp256k1} from '@noble/curves/secp256k1';
import {fromB64, toB64, toHEX} from '@mysten/bcs';
import {sha256} from '@noble/hashes/sha256';
import {SIGNATURE_SCHEME_TO_FLAG} from "@mysten/sui.js/src/cryptography/signature";
import {toBytes} from "@noble/hashes/utils";

const {execSync} = require('child_process');
const {BCS, getSuiMoveConfig} = require("@mysten/bcs");
const packagePath = "../main_package";

const screenerAddr = "0x93f30968734f710b9fd193d877ddff24d48bc8ac2568886488c981ab2ca9876d";
const signature = "06d45ae2fea275e69d9a219bcae991d2f99e5535321c4bb0c8d30c39bf4d290b1e2b2e706ab0366f1fecbba112a0bbb606fb00ddb9941c3ae5eb32c7811691ed00"
let activeAddrKeystore = "AEJiIzZOjOgc0v82spQbP1NZQjI3SrhubRZf0VMBJMQO";
const raw = fromB64(activeAddrKeystore);
if (raw[0] !== 0 || raw.length !== PRIVATE_KEY_SIZE + 1) {
    throw new Error('invalid key');
}
const keypair = Ed25519Keypair.fromSecretKey(raw.slice(1));
const provider = new JsonRpcProvider(localnetConnection);
const signer = new RawSigner(keypair, provider);

const bcs = new BCS(getSuiMoveConfig());

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
    });
    it('set screener', async () => {
        let tx = new TransactionBlock();
        tx.moveCall({
            target: `${packageId}::deposit_manager::setScreenerPermission`,
            arguments: [
                tx.object(sharedStateObjectId),
                tx.pure(screenerAddr),
                tx.pure(true)
            ],
        });
        tx.setGasBudget(80000000);
        let resultOfExec = await signer.signAndExecuteTransactionBlock({
            transactionBlock:
            tx, options: {showObjectChanges: true, showEffects: true, showEvents: true, showInput: true}
        })
        expect(`${JSON.stringify(resultOfExec.effects.status.status, null, 2)}`).toEqual(`"success"`);
    });
    it('complete deposit', async () => {
        bcs.registerStructType("StealthAddress", {
            h1_x: BCS.U256,
            h1_y: BCS.U256,
            h2_x: BCS.U256,
            h2_y: BCS.U256
        })
        bcs.registerStructType("DepositRequest", {
            spender: BCS.ADDRESS,
            value: BCS.U64,
            deposit_addr: "StealthAddress",
            nonce: BCS.U64,
            gas_compensation: BCS.U64
        })
        let depositReqHex = bcs
            .ser("DepositRequest", {
                spender: keypair.getPublicKey().toSuiAddress(),
                value: 1000,
                deposit_addr: {
                    h1_x: 0x1,
                    h1_y: 0x1,
                    h2_x: 0x1,
                    h2_y: 0x1
                },
                nonce: 0,
                gas_compensation: 9000
            }).toString('hex');
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
                tx.pure(9000),
                tx.pure(hexToArr(signature))
            ],
        });
        tx.setGasBudget(80000000);
        let resultOfExec = await signer.signAndExecuteTransactionBlock({
            transactionBlock:
            tx, options: {showObjectChanges: true, showEffects: true, showEvents: true, showInput: true}
        })
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

function hexToArr(hexString: string): any[] {
    let arr = new Array();
    for (let i = 0; i < hexString.length; i += 2) {
        let byte = parseInt(hexString.substring(i, i + 2), 16);
        arr.push(byte);
    }
    return arr;
}
