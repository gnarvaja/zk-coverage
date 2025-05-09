# ZK-coverage

_Project created in the context of the [Noir Hackathon 2025](https://www.noirhack.com/)_

ZK-coverage is a privacy-preserving product that offers _parametric coverage_ against hurricanes or tropical storms.

The product uses [H3](https://h3geo.org/) Indexes (at different levels) to encode the user's location, the pricing areas, and the regions affected by the hurricanes.

The user's location is kept private always. Only a [level 2](https://wolf-h3-viewer.glitch.me/?lat=25.7825453&lng=-80.3079664&zoom=2) (~45.000 km2) area is disclosed on-chain for risk limit reasons.

When a hurricane happens, we will compute the affected areas with a predefined algorithm and publish them. Then, the users will be able to claim the policies and receive a payout without revealing their locations.

## How does it work?

First, we will have a _price list_ that includes a list of pairs (h3-index, risk bucket) for the coverage area.
The risk bucket defines the parameters that affect the price of the policy for a given amount covered. See https://docs.ensuro.co/ensuro-docs/smart-contracts/policy#premium-split for an explanation of the different parameters and how they affect the premium paid.

Then the user goes to the website, selects the location of his home (or any other location he wants to protect), which will be encoded as a high-precision h3 index (level 11 or 12).

Checking the price list, he will know the price of the coverage for a given exposure amount and duration. To acquire the coverage, he will send a zk-proof that attests:

1. His location is within a given risk bucket
2. His location is within a given H3 level 2 index
3. The hash of his location combined with a salt (also secret) is H.

With the zk-proof and these outputs, he will acquire a Policy on-chain that will be backed by Ensuro.

Then, for every storm event (we will fetch the data from HURDAT2), we will compute the affected regions as a list of pairs (h3 index, severity), where the severity maps to a percentage of the total policy exposure that will be paid out to a user in that location. The Merkle root of this list will be published on-chain.

To claim the policy, the user will have to submit a zk-proof that attests:

1. His location is within (h3 child) an affected area that has a given severity.
2. The hash of his location combined with a salt (also secret) is H.

This proof will be sent on-chain to the risk module, which will verify the proof and trigger the policy, releasing the payout.

## ZK-proofs signatures

### Policy Acquisition

```noir
/// Proofs the user can acquire a policy with a given risk bucket.
///
/// # Arguments
///
/// * `user_location` - The location of the user's property that will be protected, encoded as a level 12 H3 index
/// * `salt` - A secret salt chosen by the user to hide his location
/// * `user_location_hash` - hash(user_location, salt) that will be public and stored in the policy.
/// * `price_list_merkle_root` - Merkle root of the price list that was published
/// * `price_area` - H3 index of a price area included in the price list
/// * `risk_bucket` - The risk bucket that corresponds to the selected price area
/// * `merkle_path` - Merkle path for the pair (price_area, risk_bucket) that is member of the price_list_merkle_root
/// * `risk_limit_area` - Level 2 H3 index that will be used for risk allocation limits.
fn main(user_location: Field,
        salt: Field,
        pub user_location_hash: Field,
        pub price_list_merkle_root: Field,
        price_area: Field,
        pub risk_bucket: Field,
        merkle_path: [Field; 10],
        pub risk_limit_area: Field
) {
    ...
}
```

### Policy Claim

```noir
/// Proofs that the user was affected by a storm.
///
/// # Arguments
///
/// * `user_location` - The location of the user's property that will be protected, encoded as a level 12 H3 index
/// * `salt` - A secret salt chosen by the user to hide his location
/// * `user_location_hash` - hash(user_location, salt) that will be public and stored in the policy.
/// * `affected_list_merkle_root` - Merkle root of the price list that was published
/// * `affected_area` - H3 index of an affected area included in the affected list
/// * `severity` - The severity corresponding to the affected_area
/// * `merkle_path` - Merkle path for the pair (affected_area, severity) that is member of the affected_list_merkle_root
fn main(user_location: Field,
        salt: Field,
        pub user_location_hash: Field,
        pub affected_list_merkle_root: Field,
        affected_area: Field,
        pub severity: Field,
        merkle_path: [Field; 10]
) {
    ...
}
```

## Components

### ZK-Coverage Smart Contract

This will be a smart contract that will be integrated with the [Ensuro protocol](https://ensuro.co) to create and claim the policies.

### Price list generation

This will be an off-chain process (probably in Python) that will analyze the historical storm data (from [HURDAT2](https://www.nhc.noaa.gov/data/#hurdat)) and it will assign price buckets to the different covered locations. The list will be published off-chain, and the Merkle root of that list will be stored on-chain (on the ZK-Coverage Smart contract).

### Front-end - Policy acquisition

This will be the user-facing component where the user will select the address of their home, which will be encoded as an H3 level 12 location.

Then, using the price list, it will compute the premium to be paid for a given amount of coverage.

If the user confirms, it will generate the zk-proof that will be submitted to the ZK-Coverage smart contract that will create the policy.

### Affected areas generation

This will be an off-chain process (probably in Python) that will analyze the storm data (from [HURDAT2](https://www.nhc.noaa.gov/data/#hurdat)) and for each storm in the coverage period, it will generate the list of affected areas and assign a severity to each of them. The list will be published off-chain, and the Merkle root of that list will be stored on-chain (on the ZK-Coverage Smart contract).

### Front-end - Policy claim

Here, the user will introduce their location and will see the storm that affected this location and the payout he is entitled to claim.

By entering the salt, he will be able to generate the zk-proof that will be submitted to the ZK-coverage smart contract that, after verifying the proof, will trigger the policy and release the payout.

## Deployments

### Live Demo

https://zkcoverage.web.app/

### Sepolia

Smart contracts deployed:

- ZkCoverage: https://sepolia.etherscan.io/address/0x7d78fb87a9a4cc1e45a1c95e7feeca39b25d2c9f#code
- AcquisitionVerifier: https://sepolia.etherscan.io/address/0x50e4aB637F1a3Fa944A0e014fc34A10cC24a1bB4
- ClaimVerifier: https://sepolia.etherscan.io/address/0xcb0485bd2adE1E7CF45fF57e90271eBD19683167

