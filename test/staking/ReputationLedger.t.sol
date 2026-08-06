// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/access/NebulaAccessControl.sol";
import "../../src/staking/ReputationLedger.sol";

contract ReputationLedgerTest is Test {
    NebulaAccessControl accessControl;
    ReputationLedger reputationLedger;

    address admin = address(0x1);
    address validator1 = address(0x10);
    address disputeAdmin = address(0x30);
    address nonValidator = address(0x99);

    event VerificationRecorded(address indexed validator);
    event SuccessfulDisputeRecorded(address indexed validator);
    event FailedDisputeRecorded(address indexed validator);
    event SlashRecorded(address indexed validator);

    function setUp() public {
        vm.startPrank(admin);
        accessControl = new NebulaAccessControl(admin);

        accessControl.grantValidator(validator1);
        accessControl.grantDispute(disputeAdmin);
        vm.stopPrank();

        reputationLedger = new ReputationLedger(address(accessControl));
    }

    function testRecordVerification() public {
        vm.startPrank(disputeAdmin);
        vm.expectEmit(true, false, false, false);
        emit VerificationRecorded(validator1);

        reputationLedger.recordVerification(validator1);
        vm.stopPrank();

        ReputationLedger.Reputation memory rep = reputationLedger.getReputation(validator1);
        assertTrue(rep.exists);
        assertEq(rep.validator, validator1);
        assertEq(rep.successfulVerifications, 1);
        assertEq(rep.lastUpdated, uint64(block.timestamp));
    }

    function testRecordSuccessfulDispute() public {
        vm.startPrank(disputeAdmin);
        vm.expectEmit(true, false, false, false);
        emit SuccessfulDisputeRecorded(validator1);

        reputationLedger.recordSuccessfulDispute(validator1);
        vm.stopPrank();

        ReputationLedger.Reputation memory rep = reputationLedger.getReputation(validator1);
        assertTrue(rep.exists);
        assertEq(rep.successfulDisputes, 1);
    }

    function testRecordFailedDispute() public {
        vm.startPrank(disputeAdmin);
        vm.expectEmit(true, false, false, false);
        emit FailedDisputeRecorded(validator1);

        reputationLedger.recordFailedDispute(validator1);
        vm.stopPrank();

        ReputationLedger.Reputation memory rep = reputationLedger.getReputation(validator1);
        assertTrue(rep.exists);
        assertEq(rep.failedDisputes, 1);
    }

    function testRecordSlash() public {
        vm.startPrank(disputeAdmin);
        vm.expectEmit(true, false, false, false);
        emit SlashRecorded(validator1);

        reputationLedger.recordSlash(validator1);
        vm.stopPrank();

        ReputationLedger.Reputation memory rep = reputationLedger.getReputation(validator1);
        assertTrue(rep.exists);
        assertEq(rep.slashes, 1);
    }

    function testUnauthorizedUpdateReverts() public {
        vm.prank(validator1);
        vm.expectRevert(ReputationLedger.NotDisputeRole.selector);
        reputationLedger.recordVerification(validator1);
    }

    function testNonValidatorRevert() public {
        vm.prank(disputeAdmin);
        vm.expectRevert(ReputationLedger.NotValidator.selector);
        reputationLedger.recordVerification(nonValidator);
    }

    function testCounterAccumulation() public {
        vm.startPrank(disputeAdmin);
        reputationLedger.recordVerification(validator1);
        reputationLedger.recordVerification(validator1);
        reputationLedger.recordSuccessfulDispute(validator1);
        reputationLedger.recordFailedDispute(validator1);
        reputationLedger.recordSlash(validator1);
        vm.stopPrank();

        ReputationLedger.Reputation memory rep = reputationLedger.getReputation(validator1);
        assertEq(rep.successfulVerifications, 2);
        assertEq(rep.successfulDisputes, 1);
        assertEq(rep.failedDisputes, 1);
        assertEq(rep.slashes, 1);
    }

    function testGetterValidation() public {
        ReputationLedger.Reputation memory rep = reputationLedger.getReputation(nonValidator);
        assertFalse(rep.exists);
        assertEq(rep.successfulVerifications, 0);
    }
}
