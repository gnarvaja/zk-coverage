// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ZkCoverage} from "../src/ZkCoverage.sol";
import {ZkCoverageHarness} from "../src/ZkCoverageHarness.sol";
import {IVerifier} from "../src/interfaces/IVerifier.sol";
import {AcquisitionVerifier} from "../src/verifiers/AcquisitionVerifier.sol";
import {ClaimVerifier} from "../src/verifiers/ClaimVerifier.sol";

contract DeployScript is Script {
    ZkCoverage public coverage;
    IVerifier public claimVerifier;
    IVerifier public acquisitionVerifier;

    /// Address of the account that signed the priceList
    address public constant priceAdmin = 0xF9341f8cB3c0476E97C7129d9FC66D41ad58366c;
    /// Address of the account that signed the claimsLists
    address public constant claimAdmin = 0xF9341f8cB3c0476E97C7129d9FC66D41ad58366c;

    address public constant riskModule = 0xDcf70793d758EFD3742e860ccf05b9EfbC9a9462;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        claimVerifier = IVerifier(address(new ClaimVerifier()));
        acquisitionVerifier = IVerifier(address(new AcquisitionVerifier()));

        // coverage = new ZkCoverage(riskModule, address(acquisitionVerifier), address(claimVerifier));
        coverage = new ZkCoverageHarness(riskModule, address(acquisitionVerifier), address(claimVerifier));
        // Grant roles to other admins
        coverage.grantRole(coverage.DEFAULT_ADMIN_ROLE(), 0xD758aF6BFC2f0908D7C5f89942be52C36a6b3cab); // Guillo
        coverage.grantRole(coverage.DEFAULT_ADMIN_ROLE(), 0x46501ca5C8b401785840D54D2F8F0C386e15D500); // Otto
        // Grant us permissions to change the verifiers
        coverage.grantRole(coverage.VERIFIER_ADMIN_ROLE(), 0xD758aF6BFC2f0908D7C5f89942be52C36a6b3cab); // Guillo
        coverage.grantRole(coverage.VERIFIER_ADMIN_ROLE(), 0x46501ca5C8b401785840D54D2F8F0C386e15D500); // Otto
        // Grant roles to pricer and claim admin account
        coverage.grantRole(coverage.PRICER_ROLE(), priceAdmin);
        coverage.grantRole(coverage.CLAIM_AREAS_ROLE(), claimAdmin);

        vm.stopBroadcast();
    }
}
