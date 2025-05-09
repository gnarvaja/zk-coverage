use binary_merkle_root::binary_merkle_root;
use std::hash::poseidon::bn254::hash_2 as poseidon2;

global MAX_DEPTH: u32 = 10;
global USER_RESOLUTION: u8 = 12;

// Check https://observablehq.com/@nrabinowitz/h3-index-bit-layout?collection=@nrabinowitz/h3
// 52 = 3 * 15 + 7
// RESET_RESOLUTION will be all ones but bits 8 to 11 that will be zero
global RESET_RESOLUTION: u64 = !(15 << 52);
global GET_RESOLUTION: u64 = (15 << 52);
// Generated with [int("000" * i + "111" * (15 - i), 2) for i in range(15)]
global DIGITS_MASK: [H3Index; 15] = [
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

fn get_resolution(h3_index: H3Index) -> u8 {
    ((h3_index & GET_RESOLUTION) >> 52) as u8
}

fn set_resolution(h3_index: H3Index, level: u64) -> H3Index {
    let ret: u64 = (h3_index & RESET_RESOLUTION) + (level << 52);
    ret
}

fn find_parent(h3_index: H3Index, level: u64) -> H3Index {
    let ret: H3Index = set_resolution(h3_index, level) | DIGITS_MASK[level];
    ret
}

/// Proofs the user can acquire a policy with a given risk bucket.
///
/// # Arguments
///
/// * `user_location_l12` - The location of the user's property that will be protected, encoded as a level 12 H3 index
/// * `salt` - A secret salt chosen by the user to hide his location
/// * `user_location_hash` - hash(user_location, salt) that will be public and stored in the policy.
/// * `price_merkle_root` - Merkle root of the price list that was published
/// * `merkle_proof_depth` - The depth of the Merkle proof
/// * `merkle_proof_indices` - The indices of the Merkle proof
/// * `merkle_proof_siblings` - The siblings of the Merkle proof
/// * `price_area_level` - The level of the matching price area
/// * `risk_bucket` - The risk corresponding to the use location, used to generate the leaf of the Merkle tree hash(ancestor_area, risk_bucket)
/// * `risk_limit_area_l2` - Level 2 H3 index that will be used for risk allocation limits.
fn main(
    user_location_l12: H3Index,
    salt: Field,
    user_location_hash: pub Field,
    // Merkle Tree related parameters
    price_merkle_root: pub Field,
    merkle_proof_depth: u32,
    merkle_proof_indices: [u1; MAX_DEPTH],
    merkle_proof_siblings: [Field; MAX_DEPTH],
    price_area_level: u8,
    risk_bucket: pub Field,
    risk_limit_area_l2: pub H3Index,
) {
    // Assert user knows preimage of location_hash
    let location_hash = poseidon2([user_location_l12 as Field, salt]);
    assert(location_hash == user_location_hash);
    assert(get_resolution(user_location_l12) == USER_RESOLUTION);

    // Assert location is inside the risk limit area
    let user_location_l2 = find_parent(user_location_l12, 2);
    assert(user_location_l2 == risk_limit_area_l2);

    // Assert membership in price merkle tree
    assert(price_area_level < USER_RESOLUTION);  // Check is a parent area
    let ancestor_area = find_parent(user_location_l12, price_area_level as u64) as Field;
    let leaf = poseidon2([ancestor_area, risk_bucket]);
    let merkle_root = binary_merkle_root(
        poseidon2,
        leaf,
        merkle_proof_depth,
        merkle_proof_indices,
        merkle_proof_siblings,
    );
    assert(merkle_root == price_merkle_root);
}

// Merkle proof generated in scripts/merkle/test_tree_index0_depth1.js
#[test]
fn test_tree_index0_depth1_valid() {
    main(
        0x8ca8800000289ff,
        2025,
        poseidon2([0x8ca8800000289ff, 2025]),
        9987659554087958193987246512218169607252654618198392791162826453558483348086,
        1 as u32,
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [
            2505787336919493057145591913263933834700353798156898359912782604888314659247,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
        ],
        6,
        2,
        0x82a887fffffffff,
    )
}

// Merkle proof generated in scripts/merkle/test_tree_index0_depth8.js
#[test]
fn test_tree_index0_depth8_valid() {
    main(
        0x8ca8800000289ff,
        2025,
        poseidon2([0x8ca8800000289ff, 2025]),
        8544077265966087262208685397730076081548467769413373190673422409766070659356,
        8 as u32,
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [
            2505787336919493057145591913263933834700353798156898359912782604888314659247,
            17197790661637433027297685226742709599380837544520340689137581733613433332983,
            7960741062684589801276390367952372418815534638314682948141519164356522829957,
            12149159335560625006476125566762465580257337488628181926934192232419917268760,
            2020935252456155598848425276294751505466146638036638155206112299564315402212,
            11143624026017686212540665545555316314886452709170340516688199167637290752786,
            8778905279355096290503828655318104734077349614888001386803571748934481657802,
            9624841562534685402628903819440959715283864469798274214385279820446073687422,
            0,
            0,
        ],
        6,
        2,
        0x82a887fffffffff,
    )
}

// Merkle proof generated in scripts/merkle/test_tree_index3_depth8.js
#[test]
fn test_tree_index3_depth8_valid() {
    main(
        0x8ca8800000289ff,
        2025,
        poseidon2([0x8ca8800000289ff, 2025]),
        16459843010275729092510049756462230976175705788716954125504957416311967992294,
        8 as u32,
        [0, 1, 0, 0, 0, 0, 0, 0, 0, 0],
        [
            2,
            13267165646834346981583549280089398528275418421787698075016576435152407298767,
            14359006873358239183620888069673439888371756553939494794830221945483065556246,
            13002569596205906143166249813631720353637999842000003046014585538574267969544,
            16447453120319737130003802166891368637543897345716930279214646665765632650446,
            7637600339054305449869348848028125811830439669090597320111319772670391347543,
            21226855299492931741175759980420775676203279715531196117038590257560718443651,
            4112489078704781209917926949084005588738998580168520934704323708142102303166,
            0,
            0,
        ],
        6,
        2,
        0x82a887fffffffff,
    )
}

// Merkle proof generated in scripts/merkle/test_tree_index0_depth1.js
// Expected indices: [0 0 0 0 0 0 0 0]
#[test(should_fail)]
fn test_tree_depth0_invalid_index() {
    main(
        0x8ca8800000289ff,
        2025,
        poseidon2([0x8ca8800000289ff, 2025]),
        9987659554087958193987246512218169607252654618198392791162826453558483348086,
        1 as u32,
        [1, 0, 1, 0, 1, 0, 0, 0, 0, 0],
        [
            2505787336919493057145591913263933834700353798156898359912782604888314659247,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
        ],
        6,
        2,
        0x82a887fffffffff,
    )
}

// Merkle proof generated in scripts/merkle/test_tree_index0_depth1.js
// Expected proof: 9987659554087958193987246512218169607252654618198392791162826453558483348086
#[test(should_fail)]
fn test_tree_invalid_proof() {
    main(
        0x8ca8800000289ff,
        2025,
        poseidon2([0x8ca8800000289ff, 2025]),
        9987659554087958193987246512218169607252654618198392791162826453558483348085,
        1 as u32,
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [
            2505787336919493057145591913263933834700353798156898359912782604888314659247,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
        ],
        6,
        2,
        0x82a887fffffffff,
    )
}

// Merkle proof generated in scripts/merkle/test_tree_index0_depth1.js
// Expected hash: 17385625702787583685708553472669385170687820988463563134430546447441607139157
#[test(should_fail)]
fn test_main_invalid_hash() {
    main(
        0x8ca8800000289ff,
        2025,
        poseidon2([0x8ca8800000289ff, 2025]) + 1,
        9987659554087958193987246512218169607252654618198392791162826453558483348086,
        1 as u32,
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [
            2505787336919493057145591913263933834700353798156898359912782604888314659247,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
        ],
        6,
        2,
        0x82a887fffffffff,
    )
}

// Merkle proof generated in scripts/merkle/test_tree_index1_depth1.js
#[test]
fn test_tree_index1_depth1_valid() {
    main(
        0x8ca8800000289ff,
        2025,
        poseidon2([0x8ca8800000289ff, 2025]),
        4834552172525200349252524841132228226911387931864173416015877393683756400922,
        1 as u32,
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [
            2505787336919493057145591913263933834700353798156898359912782604888314659247,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
        ],
        6,
        2,
        0x82a887fffffffff,
    )
}

// Merkle proof generated in scripts/merkle/test_tree_index1_depth8.js
#[test]
fn test_tree_index1_depth8_valid() {
    main(
        0x8ca8800000289ff,
        2025,
        poseidon2([0x8ca8800000289ff, 2025]),
        18800052147126938049041814701223124518921691655927767576643187252463137499052,
        8 as u32,
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [
            2505787336919493057145591913263933834700353798156898359912782604888314659247,
            17197790661637433027297685226742709599380837544520340689137581733613433332983,
            7960741062684589801276390367952372418815534638314682948141519164356522829957,
            12149159335560625006476125566762465580257337488628181926934192232419917268760,
            2020935252456155598848425276294751505466146638036638155206112299564315402212,
            11143624026017686212540665545555316314886452709170340516688199167637290752786,
            8778905279355096290503828655318104734077349614888001386803571748934481657802,
            9624841562534685402628903819440959715283864469798274214385279820446073687422,
            0,
            0,
        ],
        6,
        2,
        0x82a887fffffffff,
    )
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
    assert(get_resolution(h3_l12) == 12);
    assert(get_resolution(h3_l11) == 11);
}
