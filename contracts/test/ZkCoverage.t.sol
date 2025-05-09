// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ZkCoverage} from "../src/ZkCoverage.sol";
import {AcquisitionVerifier} from "../src/verifiers/AcquisitionVerifier.sol";
import {ClaimVerifier} from "../src/verifiers/ClaimVerifier.sol";
import {Policy} from "@ensuro/Policy.sol";

contract policyTriggerTest is Test {
    ZkCoverage public zkCoverage;
    AcquisitionVerifier public acquisitionVerifier;
    ClaimVerifier public claimVerifier;

    function setUp() public {
        acquisitionVerifier = new AcquisitionVerifier();
        claimVerifier = new ClaimVerifier();
        zkCoverage = new ZkCoverage(address(0), address(acquisitionVerifier), address(claimVerifier));
    }

    function test_acquisition_wrong_length() public {
        /*
        bytes32 user_location_hash = 0x2bf7e4809be8dfcbd285caae1ed85de71cd24c7f3af22a52a5a8870da7b4a726;
        bytes memory proof = new bytes(0);
        vm.expectRevert(bytes4(keccak256("ProofLengthWrong()")));
        zkCoverage.newPolicy(
            0, user_location_hash, bytes32(0), bytes32(uint256(uint64(0x82a807fffffffff))), 0, address(0), proof
        );
      */
    }

    function test_acquisition_invalid_proof() public {
        /*
        bytes32 user_location_hash = 0x2bf7e4809be8dfcbd285caae1ed85de71cd24c7f3af22a52a5a8870da7b4a726;
        string memory path = "../circuits/acquisition/target/acquisition_proof.bin";
        bytes memory proof = vm.readFileBinary(path);
        proof[12] = bytes1(uint8(1));
        vm.expectRevert();
        zkCoverage.newPolicy(
            0, user_location_hash, 1, bytes32(uint256(uint64(0x82a807fffffffff))), 0, address(0), proof
        );
      */
    }

    function test_acquisition_valid_proof() public {
        /*
        bytes32 user_location_hash = 0x2bf7e4809be8dfcbd285caae1ed85de71cd24c7f3af22a52a5a8870da7b4a726;
        string memory path = "../circuits/acquisition/target/acquisition_proof.bin";
        bytes memory proof = vm.readFileBinary(path);
        zkCoverage.newPolicy(
            0, user_location_hash, 1, bytes32(uint256(uint64(0x82a807fffffffff))), 0, address(0), proof
        );
      */
    }

    function test_claim_wrong_length() public {
        /*
        bytes32 user_location_hash = 0x2bf7e4809be8dfcbd285caae1ed85de71cd24c7f3af22a52a5a8870da7b4a726;
        bytes memory proof = new bytes(0);
        vm.expectRevert(bytes4(keccak256("ProofLengthWrong()")));
        zkCoverage.claim(user_location_hash, 1, 0, proof);
      */
    }

    function test_claim_invalid_proof() public {
        /*
        bytes32 user_location_hash = 0x2bf7e4809be8dfcbd285caae1ed85de71cd24c7f3af22a52a5a8870da7b4a726;
        string memory path = "../circuits/claim/target/claim_proof.bin";
        bytes memory proof = vm.readFileBinary(path);
        proof[12] = bytes1(uint8(1));
        vm.expectRevert();
        zkCoverage.claim(user_location_hash, 1, 0, proof);
      */
    }

    function test_claim_valid_proof() public {
        /*
        bytes32 user_location_hash = 0x2bf7e4809be8dfcbd285caae1ed85de71cd24c7f3af22a52a5a8870da7b4a726;
        string memory path = "../circuits/claim/target/claim_proof.bin";
        bytes memory proof = vm.readFileBinary(path);
        zkCoverage.claim(user_location_hash, 1, 0, proof);
      */
    }
}
