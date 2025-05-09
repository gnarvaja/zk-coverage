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

## ZK circuits

### Policy Acquisition

![image](https://github.com/user-attachments/assets/26588c3a-222c-4704-b3d3-faa57165ee09)

https://github.com/gnarvaja/zk-coverage/blob/main/circuits/acquisition/src/main.nr

### Policy Claim

![image](https://github.com/user-attachments/assets/16f0b048-41fa-49ad-ba67-4af1e12f1274)

https://github.com/gnarvaja/zk-coverage/blob/main/circuits/claim/src/main.nr

## Components

### ZK-Coverage Smart Contract

This will be a smart contract that will be integrated with the [Ensuro protocol](https://ensuro.co) to create and claim the policies.

### Price list generation

This will be an off-chain process (probably in Python) that will analyze the historical storm data (from [HURDAT2](https://www.nhc.noaa.gov/data/#hurdat)) and it will assign price buckets to the different covered locations. The list will be published off-chain, and the Merkle root of that list will be stored on-chain (on the ZK-Coverage Smart contract).

See https://github.com/gnarvaja/zk-coverage/tree/main/hurdat2#readme

### Front-end - Policy acquisition

This will be the user-facing component where the user will select the address of their home, which will be encoded as an H3 level 12 location.

Then, using the price list, it will compute the premium to be paid for a given amount of coverage.

If the user confirms, it will generate the zk-proof that will be submitted to the ZK-Coverage smart contract that will create the policy.

https://zkcoverage.web.app/

### Affected areas generation

This will be an off-chain process (probably in Python) that will analyze the storm data (from [HURDAT2](https://www.nhc.noaa.gov/data/#hurdat)) and for each storm in the coverage period, it will generate the list of affected areas and assign a severity to each of them. The list will be published off-chain, and the Merkle root of that list will be stored on-chain (on the ZK-Coverage Smart contract).

See https://github.com/gnarvaja/zk-coverage/tree/main/hurdat2#readme

### Front-end - Policy claim

Here, the user will introduce their location and will see the storm that affected this location and the payout he is entitled to claim.

By entering the salt, he will be able to generate the zk-proof that will be submitted to the ZK-coverage smart contract that, after verifying the proof, will trigger the policy and release the payout.

## Deployments

### Live Demo

https://zkcoverage.web.app/

### Sepolia

Smart contracts deployed:

- ZkCoverage: https://sepolia.etherscan.io/address/0x1f75B3Af686776C80D7f0c03885F19849c260EcC#code
- AcquisitionVerifier: https://sepolia.etherscan.io/address/0xE1Db291F80633b65cA0bB1c8A347F635bbef5B9c
- ClaimVerifier: https://sepolia.etherscan.io/address/0x3a9eA402798f42896ECB0dBdf249ff558bF253f0
