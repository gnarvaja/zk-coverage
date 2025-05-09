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
    bytes32 public constant VERIFIER_ADMIN_ROLE = keccak256("VERIFIER_ADMIN_ROLE");
    uint256 internal constant WAD = 1e18;

    IVerifier public acquisitionVerifier;
    IVerifier public claimVerifier;
    TrustfulRiskModule public riskModule;
    uint96 internal internalId;

    struct SignedMT {
        bytes32 merkleRoot;
        uint40 validFrom;
        uint40 validTo;
        bytes32 signatureR;
        bytes32 signatureVS;
    }

    error InvalidProof();
    error PriceExpired();
    error ClaimNotValid();

    event PolicyAcquired(uint256 indexed policyId, uint64 indexed riskArea);
    event PolicyClaimed(uint256 indexed policyId, uint256 severity);
    event ClaimVerifierChanged(IVerifier oldVerifier, IVerifier newVerifier);
    event AcquisitionVerifierChanged(IVerifier oldVerifier, IVerifier newVerifier);

    constructor(address _riskModule, address _acquisitionVerifier, address _claimVerifier) {
        riskModule = TrustfulRiskModule(_riskModule);
        acquisitionVerifier = IVerifier(_acquisitionVerifier);
        claimVerifier = IVerifier(_claimVerifier);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function newPolicy(
        uint256 insuredValue,
        bytes32 userLocationHash,
        SignedMT memory priceList,
        uint256 lossProb,
        uint64 riskArea,
        uint40 expiration,
        address onBehalfOf,
        bytes calldata proof
    ) external {
        require(
            _checkAcquisitionProof(userLocationHash, priceList.merkleRoot, lossProb, riskArea, proof), InvalidProof()
        );
        // Check price list is active
        require(priceList.validFrom <= block.timestamp && priceList.validTo >= block.timestamp, PriceExpired());
        // Check price list signature
        _checkRole(PRICER_ROLE, _recoverSigner(priceList));

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

    function _recoverSigner(SignedMT memory signedMT) internal pure returns (address) {
        bytes32 message =
            ECDSA.toEthSignedMessageHash(abi.encodePacked(signedMT.merkleRoot, signedMT.validFrom, signedMT.validTo));
        return ECDSA.recover(message, signedMT.signatureR, signedMT.signatureVS);
    }

    function claim(
        Policy.PolicyData calldata policyData,
        bytes32 userLocationHash,
        uint256 severity,
        SignedMT memory storm,
        bytes calldata proof
    ) external {
        require(_checkClaimProof(userLocationHash, storm.merkleRoot, severity, proof), InvalidProof());
        // Check claim is active (policy was created before valid claim date and claim period not expired)
        require(policyData.start < storm.validFrom && block.timestamp <= storm.validTo, ClaimNotValid());
        // Check price list signature
        _checkRole(CLAIM_AREAS_ROLE, _recoverSigner(storm));

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

    function setClaimVerifier(IVerifier newVerifier) external onlyRole(VERIFIER_ADMIN_ROLE) {
        // Perhaps for a production and fully decentralized setup these method should be removed, to keep it
        // immutable, but for the hackathon it can solve some issues
        _setClaimVerifier(newVerifier);
    }

    function setAcquisitonVerifier(IVerifier newVerifier) external onlyRole(VERIFIER_ADMIN_ROLE) {
        // Perhaps for a production and fully decentralized setup these method should be removed, to keep it
        // immutable, but for the hackathon it can solve some issues
        _setAcquisitionVerifier(newVerifier);
    }

    function _setClaimVerifier(IVerifier newVerifier) internal {
        emit ClaimVerifierChanged(claimVerifier, newVerifier);
        claimVerifier = newVerifier;
    }

    function _setAcquisitionVerifier(IVerifier newVerifier) internal {
        emit AcquisitionVerifierChanged(acquisitionVerifier, newVerifier);
        acquisitionVerifier = newVerifier;
    }
}
