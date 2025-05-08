// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IVerifier} from "./interfaces/IVerifier.sol";
import {Policy} from "@ensuro/Policy.sol";
import {TrustfulRiskModule} from "@ensuro/TrustfulRiskModule.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract ZkCoverage is AccessControl {
    // Users that can sign Price Lists
    bytes32 public constant PRICER_ROLE = keccak256("PRICER_ROLE");
    // Users that can sign Claim Areas Lists
    bytes32 public constant CLAIM_AREAS_ROLE = keccak256("CLAIM_AREAS_ROLE");
    uint256 internal constant WAD = 1e18;

    IVerifier public acquisitionVerifier;
    IVerifier public claimVerifier;
    TrustfulRiskModule public riskModule;
    uint96 internal internalId;

    error InvalidProof();
    error PriceExpired();
    error ClaimNotValid();

    event PolicyAcquired(uint256 indexed policyId, uint64 indexed riskArea);
    event PolicyClaimed(uint256 indexed policyId, uint256 severity);

    constructor(address _riskModule, address _acquisitionVerifier, address _claimVerifier) {
        riskModule = TrustfulRiskModule(_riskModule);
        acquisitionVerifier = IVerifier(_acquisitionVerifier);
        claimVerifier = IVerifier(_claimVerifier);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function newPolicy(
        uint256 insuredValue,
        bytes32 userLocationHash,
        bytes32 priceMerkleRoot,
        uint40 priceValidFrom,
        uint40 priceValidTo,
        bytes32 priceSignatureR,
        bytes32 priceSignatureVS,
        uint256 lossProb,
        uint64 riskArea,
        uint40 expiration,
        address onBehalfOf,
        bytes calldata proof
    ) external {
        require(_checkAcquisitionProof(userLocationHash, priceMerkleRoot, lossProb, riskArea, proof), InvalidProof());
        // Check price list is active
        require(priceValidFrom <= block.timestamp && priceValidTo >= block.timestamp, PriceExpired());
        // Check price list signature
        _checkRole(
            PRICER_ROLE,
            _recoverSigner(priceMerkleRoot, priceValidFrom, priceValidTo, priceSignatureR, priceSignatureVS)
        );

        uint256 policyId =
            riskModule.newPolicy(insuredValue, type(uint256).max, lossProb, expiration, onBehalfOf, ++internalId);
        emit PolicyAcquired(policyId, riskArea);
    }

    function _checkAcquisitionProof(
        bytes32 userLocationHash,
        bytes32 priceMerkleRoot,
        uint256 lossProb,
        uint64 riskArea,
        bytes calldata proof
    ) internal view returns (bool) {
        bytes32[] memory publicInputs = new bytes32[](4);
        publicInputs[0] = userLocationHash;
        publicInputs[1] = priceMerkleRoot;
        publicInputs[2] = bytes32(lossProb);
        publicInputs[3] = bytes32(uint256(riskArea));
        return acquisitionVerifier.verify(proof, publicInputs);
    }

    function _recoverSigner(
        bytes32 merkleRoot,
        uint40 validFrom,
        uint40 validTo,
        bytes32 signatureR,
        bytes32 signatureVS
    ) internal pure returns (address) {
        bytes32 message = ECDSA.toEthSignedMessageHash(abi.encodePacked(merkleRoot, validFrom, validTo));
        return ECDSA.recover(message, signatureR, signatureVS);
    }

    function claim(
        Policy.PolicyData calldata policyData,
        bytes32 userLocationHash,
        uint256 severity,
        bytes32 stormMerkleRoot,
        uint40 stormValidFrom,
        uint40 stormValidTo,
        bytes32 stormSignatureR,
        bytes32 stormSignatureVS,
        bytes calldata proof
    ) external {
        require(_checkClaimProof(userLocationHash, stormMerkleRoot, severity, proof), InvalidProof());
        // Check claim is active (policy was created before valid claim date and claim period not expired)
        require(policyData.start < stormValidFrom && block.timestamp <= stormValidTo, ClaimNotValid());
        // Check price list signature
        _checkRole(
            CLAIM_AREAS_ROLE,
            _recoverSigner(stormMerkleRoot, stormValidFrom, stormValidTo, stormSignatureR, stormSignatureVS)
        );

        uint256 payout = Math.mulDiv(policyData.payout, severity, WAD);

        riskModule.resolvePolicy(policyData, payout);
        emit PolicyClaimed(policyData.id, severity);
    }

    function _checkClaimProof(bytes32 userLocationHash, bytes32 stormMerkleRoot, uint256 severity, bytes calldata proof)
        internal
        view
        returns (bool)
    {
        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = userLocationHash;
        publicInputs[1] = stormMerkleRoot;
        publicInputs[2] = bytes32(severity);
        return claimVerifier.verify(proof, publicInputs);
    }
}
