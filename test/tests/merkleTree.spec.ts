import {describe, it, expect} from "vitest";
import {IncrementalMerkleTree} from "@zk-kit/incremental-merkle-tree";
import {poseidonBN} from "@nocturne-xyz/circuit-utils";
import {sha256} from "@noble/hashes/sha256";
import {toHEX} from "@mysten/bcs";
import {hexToNumber} from "@noble/curves/abstract/utils";
import {subtreeUpdateInputsFromBatch} from "@nocturne-xyz/sdk/src/proof/subtreeUpdate";
import {bigInt256ToFieldElems} from "@nocturne-xyz/sdk";

const {BCS, getSuiMoveConfig} = require("@mysten/bcs");
const bcs = new BCS(getSuiMoveConfig());

let merkleTree = new IncrementalMerkleTree(poseidonBN,16,BigInt(0),4);

describe('test merkle tree', () => {
    it('create merkle tree', () => {
        console.log(merkleTree.root);
    });
    it('insert', () => {
        bcs.registerStructType("EncodedNote", {
            owner_H1: BCS.U256,
            owner_H2: BCS.U256,
            nonce: BCS.U64,
            value: BCS.U64
        })
        for (let n = 0; n < 2; n++) {
            let accArr = [];
            for (let i = 0; i < 16; i++){
                let note_bytes = bcs.ser("EncodedNote",{
                    owner_H1: 0x1,
                    owner_H2: 0x1,
                    nonce: 16*n+i,
                    value: 1
                }).toBytes();
                let note_hash_hex = toHEX(sha256(note_bytes))
                accArr.push(note_hash_hex);
                merkleTree.insert(hexToNumber(note_hash_hex));
            }
            let bytes = bcs.ser(["vector", BCS.HEX],accArr).toBytes();
            console.log(toHEX(sha256(bytes)));
        }
        // merkleTree.insert(hexToNumber(toHEX(sha256(bytes))));
        console.log(merkleTree.root);
    });

    it('proof tree', () => {
        let proof = merkleTree.createProof(16);
        console.log(proof)
        let batch = merkleTree.leaves.slice(16,32);
        let input = subtreeUpdateInputsFromBatch(batch,proof);
        console.log(input)
    });
    it('test bigIntToFieldElems', function () {
        // @ts-ignore
        let num = 9533201250583817767896570092866591469094150406835227552485691564931228351592n;
        let field = bigInt256ToFieldElems(num);
        console.log(field)
        console.log(merkleTree)
    });
})