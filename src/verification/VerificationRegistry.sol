// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AssetRegistry} from "../registry/AssetRegistry.sol";

contract VerificationRegistry {
    enum VerificationStatus {
        PENDING,
        VERIFIED,
        REJECTED,
        DISPUTED
    }

    struct Verification {
        bool exists;
        bytes32 verificationId;
        bytes32 assetId;
        bytes32 transcriptHash;
        bytes32 sandboxVersion;
        address requester;
        VerificationStatus status;
        uint64 createdAt;
        uint64 completedAt;
    }

    AssetRegistry public immutable assetRegistry;

    mapping(bytes32 => Verification) private verifications;

    event VerificationRequested(bytes32 indexed verificationId, bytes32 indexed assetId);
    event VerificationCompleted(bytes32 indexed verificationId, VerificationStatus status);
    event VerificationDisputed(bytes32 indexed verificationId);

    error ZeroAddress();
    error ZeroTranscriptHash();
    error ZeroSandboxVersion();
    error AssetDoesNotExist();
    error AssetInactive();
    error NotAssetOwner();
    error VerificationDoesNotExist();
    error InvalidStatusTransition();
    error InvalidCompletionStatus();

    constructor(address _assetRegistry) {
        if (_assetRegistry == address(0)) {
            revert ZeroAddress();
        }
        assetRegistry = AssetRegistry(_assetRegistry);
    }

    function requestVerification(bytes32 assetId, bytes32 transcriptHash, bytes32 sandboxVersion)
        external
        returns (bytes32 verificationId)
    {
        if (transcriptHash == bytes32(0)) {
            revert ZeroTranscriptHash();
        }
        if (sandboxVersion == bytes32(0)) {
            revert ZeroSandboxVersion();
        }

        AssetRegistry.Asset memory asset = assetRegistry.getAsset(assetId);
        if (!asset.exists) {
            revert AssetDoesNotExist();
        }
        if (!asset.active) {
            revert AssetInactive();
        }
        if (msg.sender != asset.owner) {
            revert NotAssetOwner();
        }

        verificationId = keccak256(abi.encodePacked(assetId, transcriptHash, msg.sender, block.timestamp));

        verifications[verificationId] = Verification({
            exists: true,
            verificationId: verificationId,
            assetId: assetId,
            transcriptHash: transcriptHash,
            sandboxVersion: sandboxVersion,
            requester: msg.sender,
            status: VerificationStatus.PENDING,
            createdAt: uint64(block.timestamp),
            completedAt: 0
        });

        emit VerificationRequested(verificationId, assetId);
    }

    function completeVerification(bytes32 verificationId, VerificationStatus status) external {
        Verification storage verification = verifications[verificationId];
        if (!verification.exists) {
            revert VerificationDoesNotExist();
        }
        if (verification.status != VerificationStatus.PENDING) {
            revert InvalidStatusTransition();
        }
        if (status != VerificationStatus.VERIFIED && status != VerificationStatus.REJECTED) {
            revert InvalidCompletionStatus();
        }

        verification.status = status;
        verification.completedAt = uint64(block.timestamp);

        emit VerificationCompleted(verificationId, status);
    }

    function markDisputed(bytes32 verificationId) external {
        Verification storage verification = verifications[verificationId];
        if (!verification.exists) {
            revert VerificationDoesNotExist();
        }
        if (verification.status != VerificationStatus.VERIFIED && verification.status != VerificationStatus.REJECTED) {
            revert InvalidStatusTransition();
        }

        verification.status = VerificationStatus.DISPUTED;

        emit VerificationDisputed(verificationId);
    }

    function getVerification(bytes32 verificationId) external view returns (Verification memory) {
        return verifications[verificationId];
    }
}
