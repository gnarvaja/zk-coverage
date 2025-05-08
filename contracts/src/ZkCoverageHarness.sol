// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {ZkCoverage} from "./ZkCoverage.sol";

/**
 * Class used to be able to test the internal functions
 */
contract ZkCoverageHarness is ZkCoverage {
    constructor(address _riskModule, address _acquisitionVerifier, address _claimVerifier)
        ZkCoverage(_riskModule, _acquisitionVerifier, _claimVerifier)
    {}

    function checkAcquisitionProof(
        bytes32 userLocationHash,
        bytes32 priceMerkleRoot,
        uint256 lossProb,
        uint64 riskArea,
        bytes calldata proof
    ) external view returns (bool) {
        super._checkAcquisitionProof(userLocationHash, priceMerkleRoot, lossProb, riskArea, proof);
    }

    function checkClaimProof(bytes32 userLocationHash, bytes32 stormMerkleRoot, uint256 severity, bytes calldata proof)
        external
        view
        returns (bool)
    {
        return super._checkClaimProof(userLocationHash, stormMerkleRoot, severity, proof);
    }

    function recoverSigner(
        bytes32 merkleRoot,
        uint40 validFrom,
        uint40 validTo,
        bytes32 signatureR,
        bytes32 signatureVS
    ) external pure returns (address) {
        return _recoverSigner(merkleRoot, validFrom, validTo, signatureR, signatureVS);
    }
}
