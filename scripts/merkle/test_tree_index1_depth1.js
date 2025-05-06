import { LeanIMT } from "@zk-kit/lean-imt"
import { poseidon2 } from "poseidon-lite"
import { cellToParent } from "h3-js"

const hash = (a, b) => poseidon2([a, b])
const tree = new LeanIMT(hash)

const user_location_l12 = "86a880007ffffff"
const user_location_l12_hex = "0x86a880007ffffff"
const user_location_l2 = cellToParent(user_location_l12, 2)
const salt = 2025
const user_location_hash = poseidon2([user_location_l12_hex, salt])
const risk_bucket = 2
const leafs = [
    poseidon2(["0x86a800007ffffff", 1]),
    poseidon2(["0x86a880007ffffff", risk_bucket])  
]
tree.insertMany(leafs)
const proof = tree.generateProof(1)

console.log("user_location_hash:", user_location_hash)
console.log("user_location_l2: 0x" + user_location_l2)
console.log("Proof:", proof)