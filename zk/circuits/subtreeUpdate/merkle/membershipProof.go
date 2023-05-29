package merkle

import (
	"github.com/consensys/gnark/frontend"
	"github.com/consensys/gnark/std/hash"
)

// MerkleProof for quadtree.
type MerkleProof struct {
	RootHash    frontend.Variable
	Leaf        frontend.Variable
	PathIndices [14][2]frontend.Variable
	Siblings    [14][3]frontend.Variable
}

// 16 leaves, 2 depth
func ComputeRootFromLeaves(api frontend.API, h hash.Hash, leaves [16]frontend.Variable) frontend.Variable {
	middleLevelNodes := [4]frontend.Variable{
		frontend.Variable(0),
		frontend.Variable(0),
		frontend.Variable(0),
		frontend.Variable(0),
	}
	for i := 0; i < 4; i++ {
		middleLevelNodes[i] = nodeSum(api, h, leaves[4*i], leaves[4*i+1], leaves[4*i+2], leaves[4*i+3])
	}
	return nodeSum(api, h, middleLevelNodes[0], middleLevelNodes[1], middleLevelNodes[2], middleLevelNodes[3])
}

func (mp *MerkleProof) ComputePath(api frontend.API) frontend.Variable {
	res := frontend.Variable("0")
	t := frontend.Variable("1")
	for i := 0; i < 14; i++ {
		index := api.Add(api.Mul(mp.PathIndices[i][0], frontend.Variable("2")), mp.PathIndices[i][1])
		res = api.Add(res, api.Mul(index, t))
		t = api.Mul(t, frontend.Variable("2"))
	}
	return res
}

// return 4 nodes hashSum
func nodeSum(api frontend.API, h hash.Hash, a, b, c, d frontend.Variable) frontend.Variable {

	h.Reset()
	h.Write(a, b, c, d)
	res := h.Sum()

	return res
}

func (mp *MerkleProof) VerifyProof(api frontend.API, h hash.Hash) {

	current := mp.Leaf

	for i := 0; i < len(mp.PathIndices); i++ {
		d1 := api.Lookup2(mp.PathIndices[i][0], mp.PathIndices[i][1], current, mp.Siblings[i][0], mp.Siblings[i][0], mp.Siblings[i][0])
		d2 := api.Lookup2(mp.PathIndices[i][0], mp.PathIndices[i][1], mp.Siblings[i][1], mp.Siblings[i][1], current, mp.Siblings[i][2])
		d3 := api.Lookup2(mp.PathIndices[i][0], mp.PathIndices[i][1], mp.Siblings[i][0], current, mp.Siblings[i][1], mp.Siblings[i][1])
		d4 := api.Lookup2(mp.PathIndices[i][0], mp.PathIndices[i][1], mp.Siblings[i][2], mp.Siblings[i][2], mp.Siblings[i][2], current)
		current = nodeSum(api, h, d1, d2, d3, d4)
	}

	api.AssertIsEqual(current, mp.RootHash)
}
