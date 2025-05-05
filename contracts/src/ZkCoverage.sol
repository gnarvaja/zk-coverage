// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

//import {ICoverage} from "./interfaces/ICoverage.sol";
import {IVerifier} from "./interfaces/IVerifier.sol";
import {Policy} from "@ensuro/Policy.sol";
import {TrustfulRiskModule} from "@ensuro/TrustfulRiskModule.sol";

// TODO Move this to interfaces
struct EventData {
    bytes32 root;
    uint256 timestamp;
}

contract ZkCoverage {
    IVerifier public acquisitionVerifier;
    IVerifier public claimVerifier;
    TrustfulRiskModule public riskModule;
    uint96 internal internalId;
    uint256 public eventId;
    mapping(uint256 => EventData) public events;
    bytes32 public priceRoot;

    error InvalidProof();
    error EventNotTriggered(uint256 timestamp);

    constructor(
        //address _riskModule,
        address _acquisitionVerifier,
        address _claimVerifier
    ) {
        //riskModule = TrustfulRiskModule(_riskModule);
        acquisitionVerifier = IVerifier(_acquisitionVerifier);
        claimVerifier = IVerifier(_claimVerifier);
    }

    // TODO Add access control to this
    function setPriceRoot(bytes32 _priceRoot) external {
        priceRoot = _priceRoot;
    }

    // TODO Add access control to this
    function registerEvent(
        bytes32 root,
        uint256 timestamp
    ) external {
        events[eventId] = EventData(root, timestamp);
        eventId++;
    }

    function pricePolicy(uint256 insuredValue, uint256 riskBucket) internal returns (uint256 payout, uint256 premium, uint256 lossProb) {
        // TODO Implement this
    }

    function computePayout(uint256 payout, uint256 severity) internal returns (uint256) {
        // TODO Implement this
    }

    function newPolicy(
        uint256 insuredValue,
        bytes32 userLocationHash,
        uint256 riskBucket,
        bytes32 riskArea,
        uint40 expiration,
        address onBehalfOf,
        bytes calldata proof
    ) external {
        bytes32[] memory publicInputs = new bytes32[](4);
        publicInputs[0] = userLocationHash;
        publicInputs[1] = priceRoot;
        publicInputs[2] = bytes32(uint256(riskBucket));
        publicInputs[3] = riskArea;
        if (!acquisitionVerifier.verify(proof, publicInputs)) {
            revert InvalidProof(); 
        } // TODO Check when it returns false instead of reverting

        (uint256 payout, uint256 premium, uint256 lossProb) = pricePolicy(insuredValue, riskBucket);

        uint96 id = internalId++;
        //riskModule.newPolicy(payout, premium, lossProb, expiration, onBehalfOf, id);
    }

    function claim(
        //Policy.PolicyData calldata policyData,
        bytes32 userLocationHash,
        uint256 severity,
        uint256 eventIdentifier,
        bytes calldata proof
    ) external {
        EventData memory eventData = events[eventIdentifier];
        if (eventData.timestamp == 0) {
            revert EventNotTriggered(eventData.timestamp);
        }
        // TODO Check if the event happened before the policy expiration

        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = userLocationHash;
        publicInputs[1] = eventData.root;
        publicInputs[2] = bytes32(uint256(severity));
        if (!claimVerifier.verify(proof, publicInputs)) {
            revert InvalidProof(); 
        } // TODO Check when it returns false instead of reverting

        //uint256 payout = computePayout(policyData.payout, severity);
        //riskModule.resolvePolicy(policyData, payout);
    }
}
