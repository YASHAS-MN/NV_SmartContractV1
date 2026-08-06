// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NebulaAccessControl} from "../access/NebulaAccessControl.sol";

contract ReputationLedger {
    struct Reputation {
        bool exists;
        address validator;
        uint32 successfulVerifications;
        uint32 successfulDisputes;
        uint32 failedDisputes;
        uint32 slashes;
        uint64 lastUpdated;
    }

    NebulaAccessControl public immutable accessControl;

    mapping(address => Reputation) private reputations;

    event VerificationRecorded(address indexed validator);
    event SuccessfulDisputeRecorded(address indexed validator);
    event FailedDisputeRecorded(address indexed validator);
    event SlashRecorded(address indexed validator);

    error ZeroAddress();
    error NotValidator();
    error NotDisputeRole();

    constructor(address _accessControl) {
        if (_accessControl == address(0)) {
            revert ZeroAddress();
        }
        accessControl = NebulaAccessControl(_accessControl);
    }

    function recordVerification(address validator) external {
        _validateInputs(validator);

        Reputation storage rep = reputations[validator];
        if (!rep.exists) {
            rep.exists = true;
            rep.validator = validator;
        }

        rep.successfulVerifications++;
        rep.lastUpdated = uint64(block.timestamp);

        emit VerificationRecorded(validator);
    }

    function recordSuccessfulDispute(address validator) external {
        _validateInputs(validator);

        Reputation storage rep = reputations[validator];
        if (!rep.exists) {
            rep.exists = true;
            rep.validator = validator;
        }

        rep.successfulDisputes++;
        rep.lastUpdated = uint64(block.timestamp);

        emit SuccessfulDisputeRecorded(validator);
    }

    function recordFailedDispute(address validator) external {
        _validateInputs(validator);

        Reputation storage rep = reputations[validator];
        if (!rep.exists) {
            rep.exists = true;
            rep.validator = validator;
        }

        rep.failedDisputes++;
        rep.lastUpdated = uint64(block.timestamp);

        emit FailedDisputeRecorded(validator);
    }

    function recordSlash(address validator) external {
        _validateInputs(validator);

        Reputation storage rep = reputations[validator];
        if (!rep.exists) {
            rep.exists = true;
            rep.validator = validator;
        }

        rep.slashes++;
        rep.lastUpdated = uint64(block.timestamp);

        emit SlashRecorded(validator);
    }

    function getReputation(address validator) external view returns (Reputation memory) {
        return reputations[validator];
    }

    function _validateInputs(address validator) private view {
        if (!accessControl.hasRole(accessControl.DISPUTE_ROLE(), msg.sender)) {
            revert NotDisputeRole();
        }
        if (!accessControl.hasRole(accessControl.VALIDATOR_ROLE(), validator)) {
            revert NotValidator();
        }
    }
}
