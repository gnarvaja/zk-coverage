// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

//import {ICoverage} from "./interfaces/ICoverage.sol";
import {IVerifier} from "./interfaces/IVerifier.sol";
import {Policy} from "@ensuro/Policy.sol";
import {TrustfulRiskModule} from "@ensuro/TrustfulRiskModule.sol";

struct PolicyData {
    uint256 insuredAmount;
    bytes32 userLocationHash;
    bytes32 riskBucket;
}

struct EventData {
    bytes32 root;
    uint256 timestamp;
}

contract Coverage {
    IVerifier public acquisitionVerifier;
    IVerifier public claimVerifier;
    TrustfulRiskModule public riskModule;
    uint96 internal internalId;
    mapping(bytes32 => EventData) public events;
    bytes32 public priceRoot; // TODO Add setter to this

    error InvalidProof();
    error EventNotTriggered(uint256 timestamp);

    constructor(
        address _riskModule,
        address _acquisitionVerifier,
        address _claimVerifier
    ) {
        riskModule = TrustfulRiskModule(_riskModule);
        acquisitionVerifier = IVerifier(_acquisitionVerifier);
        claimVerifier = IVerifier(_claimVerifier);
    }

    function pricePolicy(uint256 insuredValue, bytes32 riskBucket) internal returns (uint256 payout, uint256 premium, uint256 lossProb) {
        // TODO Implement this
    }

    function computePayout(uint256 payout, uint256 severity) internal returns (uint256) {
        // TODO Implement this
    }

    function newPolicy(
        uint256 insuredValue,
        bytes32 userLocationHash,
        bytes32 riskBucket,
        uint64 riskArea,
        uint40 expiration,
        address onBehalfOf,
        bytes calldata proof
    ) external {
        bytes32[] memory publicInputs = new bytes32[](4);
        publicInputs[0] = userLocationHash;
        publicInputs[1] = priceRoot;
        publicInputs[2] = riskBucket;
        publicInputs[3] = bytes32(uint256(riskArea));
        if (!acquisitionVerifier.verify(proof, publicInputs)) {
            revert InvalidProof();
        }

        (uint256 payout, uint256 premium, uint256 lossProb) = pricePolicy(insuredValue, riskBucket);

        uint96 id = internalId++;
        riskModule.newPolicy(payout, premium, lossProb, expiration, onBehalfOf, id);
    }

    function claim(
        Policy.PolicyData calldata policyData,
        bytes32 userLocationHash,
        uint256 severity,
        bytes32 eventHash,
        bytes calldata proof
    ) external {
        EventData memory eventData = events[eventHash];
        if (eventData.timestamp == 0) {
            revert EventNotTriggered(eventData.timestamp); //TODO Change this
        }

        // TODO Need to constrain severity also
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = userLocationHash;
        publicInputs[1] = eventData.root;
        if (!claimVerifier.verify(proof, publicInputs)) {
            revert InvalidProof();
        }

        uint256 payout = computePayout(policyData.payout, severity);
        riskModule.resolvePolicy(policyData, payout);
    }
}
