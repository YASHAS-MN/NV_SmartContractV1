// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NebulaAccessControl} from "../access/NebulaAccessControl.sol";

contract ConsensusRegistry {
    enum ConsensusStatus {
        PENDING,
        ACCEPTED,
        REJECTED
    }

    struct Vote {
        bool voted;
        bool verdict;
        uint64 timestamp;
    }

    struct ConsensusRecord {
        bool exists;
        bytes32 verificationId;
        uint32 totalValidators;
        uint32 approvals;
        uint32 rejections;
        ConsensusStatus status;
        uint64 finalizedAt;
    }

    NebulaAccessControl public immutable accessControl;
    uint32 public immutable quorum;

    mapping(bytes32 => ConsensusRecord) private consensus;
    mapping(bytes32 => mapping(address => Vote)) private votes;

    event ConsensusCreated(bytes32 indexed verificationId);
    event VoteSubmitted(bytes32 indexed verificationId, address indexed validator, bool verdict);
    event ConsensusFinalized(bytes32 indexed verificationId, ConsensusStatus status);

    error ZeroAddress();
    error ZeroVerificationId();
    error ConsensusDoesNotExist();
    error ConsensusAlreadyExists();
    error ConsensusAlreadyFinalized();
    error AlreadyVoted();
    error QuorumNotReached();
    error NotValidator();

    constructor(address _accessControl, uint32 _quorum) {
        if (_accessControl == address(0)) {
            revert ZeroAddress();
        }
        accessControl = NebulaAccessControl(_accessControl);
        quorum = _quorum;
    }

    function createConsensus(bytes32 verificationId, uint32 validatorCount) external {
        if (verificationId == bytes32(0)) {
            revert ZeroVerificationId();
        }
        if (consensus[verificationId].exists) {
            revert ConsensusAlreadyExists();
        }

        consensus[verificationId] = ConsensusRecord({
            exists: true,
            verificationId: verificationId,
            totalValidators: validatorCount,
            approvals: 0,
            rejections: 0,
            status: ConsensusStatus.PENDING,
            finalizedAt: 0
        });

        emit ConsensusCreated(verificationId);
    }

    function submitVote(bytes32 verificationId, bool verdict) external {
        if (!accessControl.hasRole(accessControl.VALIDATOR_ROLE(), msg.sender)) {
            revert NotValidator();
        }

        ConsensusRecord storage record = consensus[verificationId];
        if (!record.exists) {
            revert ConsensusDoesNotExist();
        }
        if (record.status != ConsensusStatus.PENDING) {
            revert ConsensusAlreadyFinalized();
        }
        if (votes[verificationId][msg.sender].voted) {
            revert AlreadyVoted();
        }

        votes[verificationId][msg.sender] = Vote({voted: true, verdict: verdict, timestamp: uint64(block.timestamp)});

        if (verdict) {
            record.approvals++;
        } else {
            record.rejections++;
        }

        emit VoteSubmitted(verificationId, msg.sender, verdict);
    }

    function finalizeConsensus(bytes32 verificationId) external {
        ConsensusRecord storage record = consensus[verificationId];
        if (!record.exists) {
            revert ConsensusDoesNotExist();
        }
        if (record.status != ConsensusStatus.PENDING) {
            revert ConsensusAlreadyFinalized();
        }
        if (record.approvals + record.rejections < quorum) {
            revert QuorumNotReached();
        }

        if (record.approvals > record.rejections) {
            record.status = ConsensusStatus.ACCEPTED;
        } else {
            record.status = ConsensusStatus.REJECTED;
        }

        record.finalizedAt = uint64(block.timestamp);

        emit ConsensusFinalized(verificationId, record.status);
    }

    function getConsensus(bytes32 verificationId) external view returns (ConsensusRecord memory) {
        return consensus[verificationId];
    }

    function hasVoted(bytes32 verificationId, address validator) external view returns (bool) {
        return votes[verificationId][validator].voted;
    }
}
