// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/access/NebulaAccessControl.sol";
import "../../src/verification/ConsensusRegistry.sol";

contract ConsensusRegistryTest is Test {
    NebulaAccessControl accessControl;
    ConsensusRegistry consensusRegistry;

    address admin = address(0x1);
    address validator1 = address(0x10);
    address validator2 = address(0x20);
    address validator3 = address(0x30);
    address nonValidator = address(0x99);

    bytes32 verificationId = keccak256("verification_1");
    uint32 quorum = 2;
    uint32 totalValidators = 3;

    event ConsensusCreated(bytes32 indexed verificationId);
    event VoteSubmitted(bytes32 indexed verificationId, address indexed validator, bool verdict);
    event ConsensusFinalized(bytes32 indexed verificationId, ConsensusRegistry.ConsensusStatus status);

    function setUp() public {
        vm.startPrank(admin);
        accessControl = new NebulaAccessControl(admin);

        accessControl.grantValidator(validator1);
        accessControl.grantValidator(validator2);
        accessControl.grantValidator(validator3);
        vm.stopPrank();

        consensusRegistry = new ConsensusRegistry(address(accessControl), quorum);
    }

    function testConsensusCreation() public {
        vm.expectEmit(true, false, false, false);
        emit ConsensusCreated(verificationId);

        consensusRegistry.createConsensus(verificationId, totalValidators);

        ConsensusRegistry.ConsensusRecord memory record = consensusRegistry.getConsensus(verificationId);
        assertTrue(record.exists);
        assertEq(record.verificationId, verificationId);
        assertEq(record.totalValidators, totalValidators);
        assertEq(record.approvals, 0);
        assertEq(record.rejections, 0);
        assertTrue(record.status == ConsensusRegistry.ConsensusStatus.PENDING);
        assertEq(record.finalizedAt, 0);
    }

    function testValidatorVote() public {
        consensusRegistry.createConsensus(verificationId, totalValidators);

        vm.prank(validator1);
        vm.expectEmit(true, true, false, true);
        emit VoteSubmitted(verificationId, validator1, true);

        consensusRegistry.submitVote(verificationId, true);

        assertTrue(consensusRegistry.hasVoted(verificationId, validator1));
        assertFalse(consensusRegistry.hasVoted(verificationId, validator2));

        ConsensusRegistry.ConsensusRecord memory record = consensusRegistry.getConsensus(verificationId);
        assertEq(record.approvals, 1);
        assertEq(record.rejections, 0);
    }

    function testNonValidatorRevert() public {
        consensusRegistry.createConsensus(verificationId, totalValidators);

        vm.prank(nonValidator);
        vm.expectRevert(ConsensusRegistry.NotValidator.selector);
        consensusRegistry.submitVote(verificationId, true);
    }

    function testDuplicateVoteRevert() public {
        consensusRegistry.createConsensus(verificationId, totalValidators);

        vm.startPrank(validator1);
        consensusRegistry.submitVote(verificationId, true);

        vm.expectRevert(ConsensusRegistry.AlreadyVoted.selector);
        consensusRegistry.submitVote(verificationId, true);
        vm.stopPrank();
    }

    function testFinalizeBeforeQuorumRevert() public {
        consensusRegistry.createConsensus(verificationId, totalValidators);

        // Only 1 vote submitted, quorum is 2
        vm.prank(validator1);
        consensusRegistry.submitVote(verificationId, true);

        vm.expectRevert(ConsensusRegistry.QuorumNotReached.selector);
        consensusRegistry.finalizeConsensus(verificationId);
    }

    function testAcceptedConsensus() public {
        consensusRegistry.createConsensus(verificationId, totalValidators);

        vm.prank(validator1);
        consensusRegistry.submitVote(verificationId, true);

        vm.prank(validator2);
        consensusRegistry.submitVote(verificationId, true);

        vm.expectEmit(true, false, false, true);
        emit ConsensusFinalized(verificationId, ConsensusRegistry.ConsensusStatus.ACCEPTED);

        consensusRegistry.finalizeConsensus(verificationId);

        ConsensusRegistry.ConsensusRecord memory record = consensusRegistry.getConsensus(verificationId);
        assertTrue(record.status == ConsensusRegistry.ConsensusStatus.ACCEPTED);
        assertEq(record.finalizedAt, uint64(block.timestamp));

        // Cannot vote after finalization
        vm.prank(validator3);
        vm.expectRevert(ConsensusRegistry.ConsensusAlreadyFinalized.selector);
        consensusRegistry.submitVote(verificationId, true);
    }

    function testRejectedConsensus() public {
        consensusRegistry.createConsensus(verificationId, totalValidators);

        vm.prank(validator1);
        consensusRegistry.submitVote(verificationId, false);

        vm.prank(validator2);
        consensusRegistry.submitVote(verificationId, false);

        vm.expectEmit(true, false, false, true);
        emit ConsensusFinalized(verificationId, ConsensusRegistry.ConsensusStatus.REJECTED);

        consensusRegistry.finalizeConsensus(verificationId);

        ConsensusRegistry.ConsensusRecord memory record = consensusRegistry.getConsensus(verificationId);
        assertTrue(record.status == ConsensusRegistry.ConsensusStatus.REJECTED);
    }

    function testGetterValidation() public {
        bytes32 dummyId = keccak256("dummy");
        ConsensusRegistry.ConsensusRecord memory record = consensusRegistry.getConsensus(dummyId);
        assertFalse(record.exists);
        assertFalse(consensusRegistry.hasVoted(dummyId, validator1));
    }
}
