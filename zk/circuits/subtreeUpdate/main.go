package main

import (
	"fmt"
	"github.com/consensys/gnark-crypto/ecc"
	"github.com/consensys/gnark/backend/groth16"
	"github.com/consensys/gnark/frontend"
	"github.com/consensys/gnark/frontend/cs/r1cs"
	"github.com/consensys/gnark/std/math/bits"
	"math/big"
	"subtreeUpdate/merkle"
	"subtreeUpdate/poseidon"
	sha2_256 "subtreeUpdate/sha256"
)

type subtreeUpdateCircuit struct {
	AccumulatorHash             frontend.Variable     `gnark:"accumulatorHash,public"`
	EncodedPathAndHash          frontend.Variable     `gnark:"encodedPathAndHash,public"`
	OldRoot                     frontend.Variable     `gnark:"oldRoot,public"`
	NewRoot                     frontend.Variable     `gnark:"newRoot,public"`
	SubtreeMembershipProof      merkle.MerkleProof    `gnark:"subtreeMembershipProof,private"`
	EmptySubtreeMembershipProof merkle.MerkleProof    `gnark:"emptySubtreeMembershipProof,private"`
	Preimage                    []frontend.Variable   `gnark:"preImage"`
	Leaves                      [16]frontend.Variable `gnark:"leaves,private"`
}

func (circuit *subtreeUpdateCircuit) Define(api frontend.API) error {
	h := poseidon.NewPoseidonHash(api)
	api.AssertIsEqual(circuit.SubtreeMembershipProof.Leaf, merkle.ComputeRootFromLeaves(api, h, circuit.Leaves))
	emptyTreeLeaves := [16]frontend.Variable{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	api.AssertIsEqual(circuit.EmptySubtreeMembershipProof.Leaf, merkle.ComputeRootFromLeaves(api, h, emptyTreeLeaves))

	EncodedPathAndHashBits := bits.ToBinary(api, circuit.EncodedPathAndHash, bits.WithNbDigits(31))
	hi := api.Add(EncodedPathAndHashBits[28], api.Mul(EncodedPathAndHashBits[29], frontend.Variable("2")), api.Mul(EncodedPathAndHashBits[30], frontend.Variable("4")))
	path := api.Sub(circuit.EncodedPathAndHash, api.Mul(hi, frontend.Variable("268435456")))
	api.AssertIsEqual(path, circuit.SubtreeMembershipProof.ComputePath(api))
	api.AssertIsEqual(path, circuit.EmptySubtreeMembershipProof.ComputePath(api))

	accumulatorHashBits := append(bits.ToBinary(api, circuit.AccumulatorHash, bits.WithNbDigits(253)), EncodedPathAndHashBits[28], EncodedPathAndHashBits[29], EncodedPathAndHashBits[30])
	accumulatorHashBytes := make([]frontend.Variable, 32)
	for i := 0; i < 32; i++ {
		accumulatorHashBytes[i] = api.Add(
			api.Mul(accumulatorHashBits[255-8*i], frontend.Variable("128")),
			api.Mul(accumulatorHashBits[254-8*i], frontend.Variable("64")),
			api.Mul(accumulatorHashBits[253-8*i], frontend.Variable("32")),
			api.Mul(accumulatorHashBits[252-8*i], frontend.Variable("16")),
			api.Mul(accumulatorHashBits[251-8*i], frontend.Variable("8")),
			api.Mul(accumulatorHashBits[250-8*i], frontend.Variable("4")),
			api.Mul(accumulatorHashBits[249-8*i], frontend.Variable("2")),
			accumulatorHashBits[248-8*i],
		)
	}
	sha256 := sha2_256.New(api)
	sha256.Reset()
	sha256.Write(circuit.Preimage[:])
	result := sha256.Sum()
	for i := range result {
		api.AssertIsEqual(result[i], accumulatorHashBytes[i])
	}
	circuit.SubtreeMembershipProof.VerifyProof(api, h)
	circuit.EmptySubtreeMembershipProof.VerifyProof(api, h)
	api.AssertIsEqual(circuit.OldRoot, circuit.EmptySubtreeMembershipProof.RootHash)
	api.AssertIsEqual(circuit.NewRoot, circuit.SubtreeMembershipProof.RootHash)
	return nil
}

func main() {
	// compiles our circuit into a R1CS
	circuit := subtreeUpdateCircuit{
		Preimage: make([]frontend.Variable, 512),
	}
	ccs, err := frontend.Compile(ecc.BN254.ScalarField(), r1cs.NewBuilder, &circuit)
	if err != nil {
		fmt.Println("circuit compile error :", err)
	}
	// groth16 zkSNARK: Setup
	pk, vk, err1 := groth16.Setup(ccs)
	if err1 != nil {
		fmt.Println("groth16 setup error :", err1)
	}
	assignment := subtreeUpdateCircuit{
		AccumulatorHash:    "4227817616696660701143006310345000348277930956434317194440135539501115863057",
		EncodedPathAndHash: "1610612737",
		OldRoot:            "14751455653696551972598626902324480412263087291693189381022091614544374105930",
		NewRoot:            "20124835335623687480810663312320583159298054440202737370297960754448161307188",
		SubtreeMembershipProof: merkle.MerkleProof{
			RootHash: "20124835335623687480810663312320583159298054440202737370297960754448161307188",
			Leaf:     "10311198283923373016267585188573545952089761138791529851438417096351462635353",
			PathIndices: [14][2]frontend.Variable{
				{0, 1},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
			},
			Siblings: [14][3]frontend.Variable{
				{
					"19308544306448469788048112111319950102602262858931723855938361542409857985469",
					"13867732332339151465497925642082178974038372652152621168903203076445231043372",
					"13867732332339151465497925642082178974038372652152621168903203076445231043372",
				},
				{
					"12482638920258770416445069396084160696706909713694235655126678204295434816978",
					"12482638920258770416445069396084160696706909713694235655126678204295434816978",
					"12482638920258770416445069396084160696706909713694235655126678204295434816978",
				},
				{
					"7166733538749145097044835779501529184583030407883999216862943858482812218900",
					"7166733538749145097044835779501529184583030407883999216862943858482812218900",
					"7166733538749145097044835779501529184583030407883999216862943858482812218900",
				},
				{
					"8105111289764799261118761045803039859349056024712051667352901171623997110135",
					"8105111289764799261118761045803039859349056024712051667352901171623997110135",
					"8105111289764799261118761045803039859349056024712051667352901171623997110135",
				},
				{
					"12848805869306190323636404927060402794679102677145469772979902111093008224192",
					"12848805869306190323636404927060402794679102677145469772979902111093008224192",
					"12848805869306190323636404927060402794679102677145469772979902111093008224192",
				},
				{
					"19558787758992270753559504143061140356952449644512620323370068802764968601369",
					"19558787758992270753559504143061140356952449644512620323370068802764968601369",
					"19558787758992270753559504143061140356952449644512620323370068802764968601369",
				},
				{
					"12390767703375336354386586159705861191789202938804190201641874256578171062369",
					"12390767703375336354386586159705861191789202938804190201641874256578171062369",
					"12390767703375336354386586159705861191789202938804190201641874256578171062369",
				},
				{
					"3137401155887568054342462681996579107920888172758509452834253176053621234802",
					"3137401155887568054342462681996579107920888172758509452834253176053621234802",
					"3137401155887568054342462681996579107920888172758509452834253176053621234802",
				},
				{
					"17246586734894168265112266963200606530710644744521791774170567941230295667185",
					"17246586734894168265112266963200606530710644744521791774170567941230295667185",
					"17246586734894168265112266963200606530710644744521791774170567941230295667185",
				},
				{
					"3579753298464347968175446964060349222759138522794226670675282662699379573112",
					"3579753298464347968175446964060349222759138522794226670675282662699379573112",
					"3579753298464347968175446964060349222759138522794226670675282662699379573112",
				},
				{
					"5502479177772891194542009540012941542204094004749813714118505924674776464255",
					"5502479177772891194542009540012941542204094004749813714118505924674776464255",
					"5502479177772891194542009540012941542204094004749813714118505924674776464255",
				},
				{
					"12023797624857124786560101326438313436313441099989701132514668150307392465028",
					"12023797624857124786560101326438313436313441099989701132514668150307392465028",
					"12023797624857124786560101326438313436313441099989701132514668150307392465028",
				},
				{
					"10263213503339600742925101484637942948945771652266922481751100499603709320717",
					"10263213503339600742925101484637942948945771652266922481751100499603709320717",
					"10263213503339600742925101484637942948945771652266922481751100499603709320717",
				},
				{
					"20734118650853257426634229445255987190193218607444720047392808113569367837624",
					"20734118650853257426634229445255987190193218607444720047392808113569367837624",
					"20734118650853257426634229445255987190193218607444720047392808113569367837624",
				},
			},
		},
		EmptySubtreeMembershipProof: merkle.MerkleProof{
			RootHash: "14751455653696551972598626902324480412263087291693189381022091614544374105930",
			Leaf:     "13867732332339151465497925642082178974038372652152621168903203076445231043372",
			PathIndices: [14][2]frontend.Variable{
				{0, 1},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
				{0, 0},
			},
			Siblings: [14][3]frontend.Variable{
				{
					"19308544306448469788048112111319950102602262858931723855938361542409857985469",
					"13867732332339151465497925642082178974038372652152621168903203076445231043372",
					"13867732332339151465497925642082178974038372652152621168903203076445231043372",
				},
				{
					"12482638920258770416445069396084160696706909713694235655126678204295434816978",
					"12482638920258770416445069396084160696706909713694235655126678204295434816978",
					"12482638920258770416445069396084160696706909713694235655126678204295434816978",
				},
				{
					"7166733538749145097044835779501529184583030407883999216862943858482812218900",
					"7166733538749145097044835779501529184583030407883999216862943858482812218900",
					"7166733538749145097044835779501529184583030407883999216862943858482812218900",
				},
				{
					"8105111289764799261118761045803039859349056024712051667352901171623997110135",
					"8105111289764799261118761045803039859349056024712051667352901171623997110135",
					"8105111289764799261118761045803039859349056024712051667352901171623997110135",
				},
				{
					"12848805869306190323636404927060402794679102677145469772979902111093008224192",
					"12848805869306190323636404927060402794679102677145469772979902111093008224192",
					"12848805869306190323636404927060402794679102677145469772979902111093008224192",
				},
				{
					"19558787758992270753559504143061140356952449644512620323370068802764968601369",
					"19558787758992270753559504143061140356952449644512620323370068802764968601369",
					"19558787758992270753559504143061140356952449644512620323370068802764968601369",
				},
				{
					"12390767703375336354386586159705861191789202938804190201641874256578171062369",
					"12390767703375336354386586159705861191789202938804190201641874256578171062369",
					"12390767703375336354386586159705861191789202938804190201641874256578171062369",
				},
				{
					"3137401155887568054342462681996579107920888172758509452834253176053621234802",
					"3137401155887568054342462681996579107920888172758509452834253176053621234802",
					"3137401155887568054342462681996579107920888172758509452834253176053621234802",
				},
				{
					"17246586734894168265112266963200606530710644744521791774170567941230295667185",
					"17246586734894168265112266963200606530710644744521791774170567941230295667185",
					"17246586734894168265112266963200606530710644744521791774170567941230295667185",
				},
				{
					"3579753298464347968175446964060349222759138522794226670675282662699379573112",
					"3579753298464347968175446964060349222759138522794226670675282662699379573112",
					"3579753298464347968175446964060349222759138522794226670675282662699379573112",
				},
				{
					"5502479177772891194542009540012941542204094004749813714118505924674776464255",
					"5502479177772891194542009540012941542204094004749813714118505924674776464255",
					"5502479177772891194542009540012941542204094004749813714118505924674776464255",
				},
				{
					"12023797624857124786560101326438313436313441099989701132514668150307392465028",
					"12023797624857124786560101326438313436313441099989701132514668150307392465028",
					"12023797624857124786560101326438313436313441099989701132514668150307392465028",
				},
				{
					"10263213503339600742925101484637942948945771652266922481751100499603709320717",
					"10263213503339600742925101484637942948945771652266922481751100499603709320717",
					"10263213503339600742925101484637942948945771652266922481751100499603709320717",
				},
				{
					"20734118650853257426634229445255987190193218607444720047392808113569367837624",
					"20734118650853257426634229445255987190193218607444720047392808113569367837624",
					"20734118650853257426634229445255987190193218607444720047392808113569367837624",
				},
			},
		},
		Preimage: make([]frontend.Variable, 512),
		Leaves: [16]frontend.Variable{
			"8156319925050744557782245694037100563564059020340687679749164066021286143836",
			"95909223809388993694993492400467043881733915630342324449340732043292438402430",
			"57414147262588752917658270334485249249923597373198409036320819119810373085930",
			"113670449272529920882410221941222150904120358535747236216730630644724274198177",
			"57398552932645399891307139678071663482334851558675487776494006109344731328249",
			"103143881793116431352669765361473968236332048388061021423670947940287385762294",
			"81612725631244049093044665038120176880687858193615788788599062677724186199322",
			"24221479052158155394601047524206106254731735391378752996520107136176279845840",
			"49556574245612851804963807434730031772247272089317479498002818782916042154755",
			"56426423107537836944547904423637136789783854836853497598720872599439703238350",
			"20422616371558051321328641762545775674999844341281317444259962231474038621913",
			"70721761249807583889417427160262976417209826966551495121360338241351139517252",
			"67154409164492473022545374284896465659184269211491885695865972146826122887517",
			"14641621711817804362131083482888050433544024750770175084260876296122465116391",
			"44449413951567356658450979332805732743618650826831158077837287657342508935054",
			"49888894850490203642386712655024128420501187089752845687448626231471203382973",
		},
	}
	bytes := make([]byte, 512)
	pre := [16]string{
		"8156319925050744557782245694037100563564059020340687679749164066021286143836",
		"95909223809388993694993492400467043881733915630342324449340732043292438402430",
		"57414147262588752917658270334485249249923597373198409036320819119810373085930",
		"113670449272529920882410221941222150904120358535747236216730630644724274198177",
		"57398552932645399891307139678071663482334851558675487776494006109344731328249",
		"103143881793116431352669765361473968236332048388061021423670947940287385762294",
		"81612725631244049093044665038120176880687858193615788788599062677724186199322",
		"24221479052158155394601047524206106254731735391378752996520107136176279845840",
		"49556574245612851804963807434730031772247272089317479498002818782916042154755",
		"56426423107537836944547904423637136789783854836853497598720872599439703238350",
		"20422616371558051321328641762545775674999844341281317444259962231474038621913",
		"70721761249807583889417427160262976417209826966551495121360338241351139517252",
		"67154409164492473022545374284896465659184269211491885695865972146826122887517",
		"14641621711817804362131083482888050433544024750770175084260876296122465116391",
		"44449413951567356658450979332805732743618650826831158077837287657342508935054",
		"49888894850490203642386712655024128420501187089752845687448626231471203382973",
	}
	for i := 0; i < 16; i++ {
		b := new(big.Int)
		b.SetString(pre[i], 10)
		bbuf := make([]byte, 32)
		b.FillBytes(bbuf)
		for j := 0; j < 32; j++ {
			bytes[32*i+j] = bbuf[j]
		}
	}
	for i := 0; i < 512; i++ {
		assignment.Preimage[i] = bytes[i]
	}
	witness, err2 := frontend.NewWitness(&assignment, ecc.BN254.ScalarField())
	if err2 != nil {
		fmt.Println("witness error :", err2)
	}
	publicWitness, err3 := witness.Public()
	if err3 != nil {
		fmt.Println("public witness error :", err3)
	}
	// groth16: Prove & Verify
	proof, err4 := groth16.Prove(ccs, pk, witness)
	if err4 != nil {
		fmt.Println("proof error :", err4)
	}
	err5 := groth16.Verify(proof, vk, publicWitness)
	if err5 != nil {
		fmt.Printf("verification failed\n")
		return
	}
	fmt.Printf("verification succeded\n")
}

//assignment := subtreeUpdateCircuit{
//	AccumulatorHash:    "1718694914574393558977766615778936430810912460753664150190225630968184786885",
//	EncodedPathAndHash: "268435456",
//	OldRoot:            "9533201250583817767896570092866591469094150406835227552485691564931228351592",
//	NewRoot:            "14751455653696551972598626902324480412263087291693189381022091614544374105930",
//	SubtreeMembershipProof: merkle.MerkleProof{
//		RootHash: "14751455653696551972598626902324480412263087291693189381022091614544374105930",
//		Leaf:     "19308544306448469788048112111319950102602262858931723855938361542409857985469",
//		PathIndices: [14][2]frontend.Variable{
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//		},
//		Siblings: [14][3]frontend.Variable{
//			{
//				"13867732332339151465497925642082178974038372652152621168903203076445231043372",
//				"13867732332339151465497925642082178974038372652152621168903203076445231043372",
//				"13867732332339151465497925642082178974038372652152621168903203076445231043372",
//			},
//			{
//				"12482638920258770416445069396084160696706909713694235655126678204295434816978",
//				"12482638920258770416445069396084160696706909713694235655126678204295434816978",
//				"12482638920258770416445069396084160696706909713694235655126678204295434816978",
//			},
//			{
//				"7166733538749145097044835779501529184583030407883999216862943858482812218900",
//				"7166733538749145097044835779501529184583030407883999216862943858482812218900",
//				"7166733538749145097044835779501529184583030407883999216862943858482812218900",
//			},
//			{
//				"8105111289764799261118761045803039859349056024712051667352901171623997110135",
//				"8105111289764799261118761045803039859349056024712051667352901171623997110135",
//				"8105111289764799261118761045803039859349056024712051667352901171623997110135",
//			},
//			{
//				"12848805869306190323636404927060402794679102677145469772979902111093008224192",
//				"12848805869306190323636404927060402794679102677145469772979902111093008224192",
//				"12848805869306190323636404927060402794679102677145469772979902111093008224192",
//			},
//			{
//				"19558787758992270753559504143061140356952449644512620323370068802764968601369",
//				"19558787758992270753559504143061140356952449644512620323370068802764968601369",
//				"19558787758992270753559504143061140356952449644512620323370068802764968601369",
//			},
//			{
//				"12390767703375336354386586159705861191789202938804190201641874256578171062369",
//				"12390767703375336354386586159705861191789202938804190201641874256578171062369",
//				"12390767703375336354386586159705861191789202938804190201641874256578171062369",
//			},
//			{
//				"3137401155887568054342462681996579107920888172758509452834253176053621234802",
//				"3137401155887568054342462681996579107920888172758509452834253176053621234802",
//				"3137401155887568054342462681996579107920888172758509452834253176053621234802",
//			},
//			{
//				"17246586734894168265112266963200606530710644744521791774170567941230295667185",
//				"17246586734894168265112266963200606530710644744521791774170567941230295667185",
//				"17246586734894168265112266963200606530710644744521791774170567941230295667185",
//			},
//			{
//				"3579753298464347968175446964060349222759138522794226670675282662699379573112",
//				"3579753298464347968175446964060349222759138522794226670675282662699379573112",
//				"3579753298464347968175446964060349222759138522794226670675282662699379573112",
//			},
//			{
//				"5502479177772891194542009540012941542204094004749813714118505924674776464255",
//				"5502479177772891194542009540012941542204094004749813714118505924674776464255",
//				"5502479177772891194542009540012941542204094004749813714118505924674776464255",
//			},
//			{
//				"12023797624857124786560101326438313436313441099989701132514668150307392465028",
//				"12023797624857124786560101326438313436313441099989701132514668150307392465028",
//				"12023797624857124786560101326438313436313441099989701132514668150307392465028",
//			},
//			{
//				"10263213503339600742925101484637942948945771652266922481751100499603709320717",
//				"10263213503339600742925101484637942948945771652266922481751100499603709320717",
//				"10263213503339600742925101484637942948945771652266922481751100499603709320717",
//			},
//			{
//				"20734118650853257426634229445255987190193218607444720047392808113569367837624",
//				"20734118650853257426634229445255987190193218607444720047392808113569367837624",
//				"20734118650853257426634229445255987190193218607444720047392808113569367837624",
//			},
//		},
//	},
//	EmptySubtreeMembershipProof: merkle.MerkleProof{
//		RootHash: "9533201250583817767896570092866591469094150406835227552485691564931228351592",
//		Leaf:     "13867732332339151465497925642082178974038372652152621168903203076445231043372",
//		PathIndices: [14][2]frontend.Variable{
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//			{0, 0},
//		},
//		Siblings: [14][3]frontend.Variable{
//			{
//				"13867732332339151465497925642082178974038372652152621168903203076445231043372",
//				"13867732332339151465497925642082178974038372652152621168903203076445231043372",
//				"13867732332339151465497925642082178974038372652152621168903203076445231043372",
//			},
//			{
//				"12482638920258770416445069396084160696706909713694235655126678204295434816978",
//				"12482638920258770416445069396084160696706909713694235655126678204295434816978",
//				"12482638920258770416445069396084160696706909713694235655126678204295434816978",
//			},
//			{
//				"7166733538749145097044835779501529184583030407883999216862943858482812218900",
//				"7166733538749145097044835779501529184583030407883999216862943858482812218900",
//				"7166733538749145097044835779501529184583030407883999216862943858482812218900",
//			},
//			{
//				"8105111289764799261118761045803039859349056024712051667352901171623997110135",
//				"8105111289764799261118761045803039859349056024712051667352901171623997110135",
//				"8105111289764799261118761045803039859349056024712051667352901171623997110135",
//			},
//			{
//				"12848805869306190323636404927060402794679102677145469772979902111093008224192",
//				"12848805869306190323636404927060402794679102677145469772979902111093008224192",
//				"12848805869306190323636404927060402794679102677145469772979902111093008224192",
//			},
//			{
//				"19558787758992270753559504143061140356952449644512620323370068802764968601369",
//				"19558787758992270753559504143061140356952449644512620323370068802764968601369",
//				"19558787758992270753559504143061140356952449644512620323370068802764968601369",
//			},
//			{
//				"12390767703375336354386586159705861191789202938804190201641874256578171062369",
//				"12390767703375336354386586159705861191789202938804190201641874256578171062369",
//				"12390767703375336354386586159705861191789202938804190201641874256578171062369",
//			},
//			{
//				"3137401155887568054342462681996579107920888172758509452834253176053621234802",
//				"3137401155887568054342462681996579107920888172758509452834253176053621234802",
//				"3137401155887568054342462681996579107920888172758509452834253176053621234802",
//			},
//			{
//				"17246586734894168265112266963200606530710644744521791774170567941230295667185",
//				"17246586734894168265112266963200606530710644744521791774170567941230295667185",
//				"17246586734894168265112266963200606530710644744521791774170567941230295667185",
//			},
//			{
//				"3579753298464347968175446964060349222759138522794226670675282662699379573112",
//				"3579753298464347968175446964060349222759138522794226670675282662699379573112",
//				"3579753298464347968175446964060349222759138522794226670675282662699379573112",
//			},
//			{
//				"5502479177772891194542009540012941542204094004749813714118505924674776464255",
//				"5502479177772891194542009540012941542204094004749813714118505924674776464255",
//				"5502479177772891194542009540012941542204094004749813714118505924674776464255",
//			},
//			{
//				"12023797624857124786560101326438313436313441099989701132514668150307392465028",
//				"12023797624857124786560101326438313436313441099989701132514668150307392465028",
//				"12023797624857124786560101326438313436313441099989701132514668150307392465028",
//			},
//			{
//				"10263213503339600742925101484637942948945771652266922481751100499603709320717",
//				"10263213503339600742925101484637942948945771652266922481751100499603709320717",
//				"10263213503339600742925101484637942948945771652266922481751100499603709320717",
//			},
//			{
//				"20734118650853257426634229445255987190193218607444720047392808113569367837624",
//				"20734118650853257426634229445255987190193218607444720047392808113569367837624",
//				"20734118650853257426634229445255987190193218607444720047392808113569367837624",
//			},
//		},
//	},
//	Preimage: make([]frontend.Variable, 512),
//	Leaves: [16]frontend.Variable{
//		"7559412695850999704437639814226631134667359700514660715427262528648684612384",
//		"66128905217727820142075711671179697108908215459957692935244063164243782161424",
//		"51015742989614192140374653588448216776344032110315281841496138794886522140476",
//		"35122383026158949466484037373710698093278849499198161694631609784776227649041",
//		"26172153391189409300153675552195806917108259526780793769448239894068277983117",
//		"26319945699020872042776764262800211039811709625022690029869433243912894238514",
//		"85459787920741173308529179304076764583420917452546478748737995277072485407899",
//		"37824474589860659728395896987471423117349358731852046326799624553171445743149",
//		"61194402916979300094031158454825880129228850504669718400883285170758259346137",
//		"24246882173524206786121934947990875280633571158623508995012743986254503068477",
//		"93199772650225608593183888507906173669398210074847791089995208298919581733292",
//		"33909163889869673678628757617712328003205266681277740626071514924998877887543",
//		"57565043458143669655443451912855736172750697736668570413272031819358780748047",
//		"37243082771427767710089206757934373481061954243301630231967571484585860082658",
//		"16563559798946351326855328924389131968545894673507955726309781333266729822892",
//		"48994785319657803905781873709543292037955196759232529867686143523322370022071",
//	},
//}

//pre := [16]string{
//	"7559412695850999704437639814226631134667359700514660715427262528648684612384",
//	"66128905217727820142075711671179697108908215459957692935244063164243782161424",
//	"51015742989614192140374653588448216776344032110315281841496138794886522140476",
//	"35122383026158949466484037373710698093278849499198161694631609784776227649041",
//	"26172153391189409300153675552195806917108259526780793769448239894068277983117",
//	"26319945699020872042776764262800211039811709625022690029869433243912894238514",
//	"85459787920741173308529179304076764583420917452546478748737995277072485407899",
//	"37824474589860659728395896987471423117349358731852046326799624553171445743149",
//	"61194402916979300094031158454825880129228850504669718400883285170758259346137",
//	"24246882173524206786121934947990875280633571158623508995012743986254503068477",
//	"93199772650225608593183888507906173669398210074847791089995208298919581733292",
//	"33909163889869673678628757617712328003205266681277740626071514924998877887543",
//	"57565043458143669655443451912855736172750697736668570413272031819358780748047",
//	"37243082771427767710089206757934373481061954243301630231967571484585860082658",
//	"16563559798946351326855328924389131968545894673507955726309781333266729822892",
//	"48994785319657803905781873709543292037955196759232529867686143523322370022071",
//}