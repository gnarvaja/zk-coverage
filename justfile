default:
  just --list

regenerate-all: regenerate-contracts-claim regenerate-proof-claim regenerate-contracts-acquisition regenerate-proof-acquisition

compile-claim:
    (cd circuits/claim/ && nargo compile)

test-claim:
    (cd circuits/claim/ && nargo test)

regenerate-contracts-claim: compile-claim
    (cd circuits/claim/ && \
    bb write_vk -b ./target/claim.json -o ./target --oracle_hash keccak && \
    bb write_solidity_verifier -k ./target/vk -o ./target/Verifier.sol && \
    sed -i -z 's/HonkVerifier/ClaimVerifier/2' ./target/Verifier.sol)
    mkdir -p contracts/src/verifiers
    cp circuits/claim/target/Verifier.sol contracts/src/verifiers/ClaimVerifier.sol

regenerate-proof-claim: compile-claim
    (cd circuits/claim/ && \
    nargo execute && \
    bb prove -b ./target/claim.json -w ./target/claim.gz -o ./target --oracle_hash keccak)
    bash clean_proof.sh 3 circuits/claim/target/proof circuits/claim/target/clean_proof.txt
    xxd -r -p circuits/claim/target/clean_proof.txt circuits/claim/target/claim_proof.bin

compile-acquisition:
    (cd circuits/acquisition/ && nargo compile)

test-acquisition:
    (cd circuits/acquisition/ && nargo test)

regenerate-contracts-acquisition: compile-acquisition
    (cd circuits/acquisition/ && \
    bb write_vk -b ./target/acquisition.json -o ./target --oracle_hash keccak && \
    bb write_solidity_verifier -k ./target/vk -o ./target/Verifier.sol && \
    sed -i -z 's/HonkVerifier/AcquisitionVerifier/2' ./target/Verifier.sol)
    mkdir -p contracts/src/verifiers
    cp circuits/acquisition/target/Verifier.sol contracts/src/verifiers/AcquisitionVerifier.sol

regenerate-proof-acquisition: compile-acquisition
    (cd circuits/acquisition/ && \
    nargo execute && \
    bb prove -b ./target/acquisition.json -w ./target/acquisition.gz -o ./target --oracle_hash keccak)
    bash clean_proof.sh 4 circuits/acquisition/target/proof circuits/acquisition/target/clean_proof.txt
    xxd -r -p circuits/acquisition/target/clean_proof.txt circuits/acquisition/target/acquisition_proof.bin

test-circuits: test-claim test-acquisition

install:
    (cd contracts && \
    forge install foundry-rs/forge-std --no-commit && \
    forge install OpenZeppelin/openzeppelin-contracts@v4.9.4 --no-commit && \
    forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v4.9.4 --no-commit && \
    forge install ensuro/ensuro --no-commit)

build-contracts:
    (cd contracts && forge build)

test-contracts:
    (cd contracts && forge test)

clean:
    (cd circuits/claim && rm -rf target)
    (cd circuits/acquisition && rm -rf target)
    (cd contracts && forge clean)
    rm -rf contracts/src/verifiers
