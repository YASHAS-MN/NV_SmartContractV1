// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VerificationRegistry} from "./VerificationRegistry.sol";

contract SealRegistry {
    struct VerificationSeal {
        bool exists;
        bytes32 sealId;
        bytes32 verificationId;
        bytes32 assetId;
        bytes32 transcriptHash;
        bytes32 sandboxVersion;
        bytes32 protocolVersion;
        bytes32 validatorSetHash;
        uint64 sealedAt;
    }

    VerificationRegistry public immutable verificationRegistry;

    mapping(bytes32 => VerificationSeal) private seals;
    mapping(bytes32 => bytes32) private verificationToSeal;

    event SealCreated(bytes32 indexed sealId, bytes32 indexed verificationId, bytes32 indexed assetId);

    error ZeroAddress();
    error ZeroValidatorSetHash();
    error ZeroProtocolVersion();
    error VerificationDoesNotExist();
    error VerificationNotVerified();
    error SealAlreadyExists();

    constructor(address _verificationRegistry) {
        if (_verificationRegistry == address(0)) {
            revert ZeroAddress();
        }
        verificationRegistry = VerificationRegistry(_verificationRegistry);
    }

    function createSeal(bytes32 verificationId, bytes32 validatorSetHash, bytes32 protocolVersion)
        external
        returns (bytes32 sealId)
    {
        if (validatorSetHash == bytes32(0)) {
            revert ZeroValidatorSetHash();
        }
        if (protocolVersion == bytes32(0)) {
            revert ZeroProtocolVersion();
        }
        if (verificationToSeal[verificationId] != bytes32(0)) {
            revert SealAlreadyExists();
        }

        VerificationRegistry.Verification memory v = verificationRegistry.getVerification(verificationId);
        if (!v.exists) {
            revert VerificationDoesNotExist();
        }
        if (v.status != VerificationRegistry.VerificationStatus.VERIFIED) {
            revert VerificationNotVerified();
        }

        sealId = keccak256(abi.encodePacked(verificationId, v.transcriptHash, block.timestamp));

        seals[sealId] = VerificationSeal({
            exists: true,
            sealId: sealId,
            verificationId: verificationId,
            assetId: v.assetId,
            transcriptHash: v.transcriptHash,
            sandboxVersion: v.sandboxVersion,
            protocolVersion: protocolVersion,
            validatorSetHash: validatorSetHash,
            sealedAt: uint64(block.timestamp)
        });

        verificationToSeal[verificationId] = sealId;

        emit SealCreated(sealId, verificationId, v.assetId);
    }

    function getSeal(bytes32 sealId) external view returns (VerificationSeal memory) {
        return seals[sealId];
    }

    function getSealByVerification(bytes32 verificationId) external view returns (VerificationSeal memory) {
        return seals[verificationToSeal[verificationId]];
    }
}
