// Code from noir standard library (https://github.com/noir-lang/noir/blob/v1.0.0-beta.3/noir_stdlib/src/merkle.nr)
// Reimplemented here because it is going to be removed from stdlib
fn compute_merkle_root<let N: u32>(leaf: Field, index: Field, hash_path: [Field; N]) -> Field {
    let index_bits: [u1; N] = index.to_le_bits();
    let mut current = leaf;
    for i in 0..N {
        let path_bit = index_bits[i] as bool;
        let (hash_left, hash_right) = if path_bit {
            (hash_path[i], current)
        } else {
            (current, hash_path[i])
        };
        current = std::hash::pedersen_hash([hash_left, hash_right]);
    }
    current
}

fn l12_to_l2(x: u64) -> u64 {
    let resolution_mask = 63050394783186944;
    let digits_mask = 549755813887;
    (x ^ resolution_mask) | digits_mask 
}

fn l12_to_l6(x: u64) -> u64 {
    let resolution_mask = 45035996273704960;
    let digits_mask = 134217727;
    (x ^ resolution_mask) | digits_mask 
}

// TODO Update args to be consistent with readme
fn main(user_location_l12: Field,
        salt: Field,
        user_location_hash: pub Field,
        price_merkle_root: pub Field,
        risk_bucket: pub Field,
        leaf_index: Field,
        hash_path: [Field; 1],
        risk_limit_area_l2: pub Field
) {
    // Assert user knows preimage of location_hash
    let location_hash = std::hash::pedersen_hash([user_location_l12, salt]);
    assert(location_hash == user_location_hash);

    // Assert location is inside the risk limit area
    let user_location_l2 = l12_to_l2(user_location_l12 as u64) as Field;
    assert(user_location_l2 == risk_limit_area_l2);

    // Assert location membership in hurricane merkle tree
    // TODO Change this to support arbitrary h3 levels
    let user_location_l6 = l12_to_l6(user_location_l12 as u64) as Field;
    let leaf = std::hash::pedersen_hash([user_location_l6, risk_bucket]);
    let merkle_root = compute_merkle_root(
        leaf, 
        leaf_index, 
        hash_path
    );
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
    let root = compute_merkle_root(
        leaf_one, 
        0x0000000000000000, 
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