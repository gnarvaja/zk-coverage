use binary_merkle_root::binary_merkle_root;
use std::hash::poseidon::bn254::hash_2 as poseidon2;

global MAX_DEPTH : u32 = 8;

// Check https://observablehq.com/@nrabinowitz/h3-index-bit-layout?collection=@nrabinowitz/h3
// 52 = 3 * 15 + 7
// RESET_RESOLUTION will be all ones but bits 8 to 11 that will be zero
global RESET_RESOLUTION : u64 = !(15 << 52);
// Generated with [int("000" * i + "111" * (15 - i), 2) for i in range(15)]
global DIGITS_MASK : [H3Index; 15] = [
    35184372088831,
    4398046511103,
    549755813887,
    68719476735,
    8589934591,
    1073741823,
    134217727,
    16777215,
    2097151,
    262143,
    32767,
    4095,
    511,
    63,
    7,
];


type H3Index = u64;

fn set_resolution(h3_index: H3Index, level: u64) -> H3Index {
    let ret : u64 = (h3_index & RESET_RESOLUTION) + (level << 52);
    ret
}

fn find_parent(h3_index: H3Index, level: u64) -> H3Index {
    let ret: H3Index = set_resolution(h3_index, level) | DIGITS_MASK[level];
    ret
}

// TODO Update args to be consistent with readme
fn main(user_location_l12: H3Index,
        salt: Field,
        user_location_hash: pub Field,
        // Merkle Tree related parameters
        price_merkle_root: pub Field,
        merkle_proof_length: u32,
        merkle_proof_indices: [u1; MAX_DEPTH],
        merkle_proof_siblings: [Field; MAX_DEPTH],
        risk_bucket: pub Field,
        risk_limit_area_l2: pub H3Index
) {
    // Assert user knows preimage of location_hash
    let location_hash = std::hash::pedersen_hash([user_location_l12 as Field, salt]);
    assert(location_hash == user_location_hash);

    // Assert location is inside the risk limit area
    let user_location_l2 = find_parent(user_location_l12, 2);
    assert(user_location_l2 == risk_limit_area_l2);

    // Assert location membership in hurricane merkle tree
    // TODO Change this to support arbitrary h3 levels
    let user_location_l6 = find_parent(user_location_l12, 6) as Field;
    let leaf = std::hash::pedersen_hash([user_location_l6, risk_bucket]);
    let merkle_root = binary_merkle_root(poseidon2, leaf, merkle_proof_length, merkle_proof_indices, merkle_proof_siblings);

    assert(merkle_root == price_merkle_root);
}

// Ignore below, just needed to get the right values to generate witness
#[test]
fn calc_merkle_root() {
    //location = -24.05379, -49.78010
    //l6 = 86a800007ffffff
    //l12 = 8ca8000000001ff
    //risk_bucket = 1

    //location = -20.63252, -42.34915
    //l6 = 86a880007ffffff
    //l12 = 8ca8800000001ff
    //risk_bucket = 2
    let h3_l6_a = 0x86a800007ffffff;
    let h3_l6_b = 0x86a880007ffffff;
    let leaf_one = std::hash::pedersen_hash([h3_l6_a, 1]);
    let leaf_two = std::hash::pedersen_hash([h3_l6_b, 2]);
    println(leaf_one);
    println(leaf_two);
    let root = binary_merkle_root(
        poseidon2,
        leaf_one,
        1,
        [1],
        [leaf_two]
    );
    println(root);
}

#[test]
fn calc_hash() {
    let h3_l12_a = 0x8ca8000000001ff;
    let salt = 2025;
    let location_hash = std::hash::pedersen_hash([h3_l12_a, salt]);
    println(location_hash);
}

#[test]
fn test_find_parent() {
    let h3_l12 = 0x8c44a112845a7ff;
    let h3_l11 = 0x8b44a112845afff;
    let h3_l6 = 0x8644a112fffffff;
    let h3_l2 = 0x8244a7fffffffff;
    assert(find_parent(h3_l12, 11) == h3_l11);
    assert(find_parent(h3_l11, 11) == h3_l11);
    assert(find_parent(h3_l12, 6) == h3_l6);
    assert(find_parent(h3_l12, 2) == h3_l2);
}
