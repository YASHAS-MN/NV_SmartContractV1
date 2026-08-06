// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AssetRegistry} from "./AssetRegistry.sol";

contract MetadataRegistry {
    struct Metadata {
        bool exists;
        bytes32 assetId;
        bytes32 metadataCID;
        bytes32 filenameHash;
        bytes32 mimeTypeHash;
        uint256 fileSize;
        uint64 registeredAt;
    }

    AssetRegistry public immutable assetRegistry;

    mapping(bytes32 => Metadata) private metadataRecords;

    event MetadataRegistered(bytes32 indexed assetId);
    event MetadataUpdated(bytes32 indexed assetId);

    error ZeroAddress();
    error ZeroMetadataCID();
    error ZeroFileSize();
    error AssetDoesNotExist();
    error AssetInactive();
    error NotAssetOwner();
    error MetadataAlreadyExists();
    error MetadataDoesNotExist();

    constructor(address _assetRegistry) {
        if (_assetRegistry == address(0)) {
            revert ZeroAddress();
        }
        assetRegistry = AssetRegistry(_assetRegistry);
    }

    function registerMetadata(
        bytes32 assetId,
        bytes32 metadataCID,
        bytes32 filenameHash,
        bytes32 mimeTypeHash,
        uint256 fileSize
    ) external {
        if (metadataCID == bytes32(0)) {
            revert ZeroMetadataCID();
        }
        if (fileSize == 0) {
            revert ZeroFileSize();
        }
        if (metadataRecords[assetId].exists) {
            revert MetadataAlreadyExists();
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

        metadataRecords[assetId] = Metadata({
            exists: true,
            assetId: assetId,
            metadataCID: metadataCID,
            filenameHash: filenameHash,
            mimeTypeHash: mimeTypeHash,
            fileSize: fileSize,
            registeredAt: uint64(block.timestamp)
        });

        emit MetadataRegistered(assetId);
    }

    function updateMetadata(bytes32 assetId, bytes32 metadataCID) external {
        if (metadataCID == bytes32(0)) {
            revert ZeroMetadataCID();
        }

        Metadata storage metadata = metadataRecords[assetId];
        if (!metadata.exists) {
            revert MetadataDoesNotExist();
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

        metadata.metadataCID = metadataCID;

        emit MetadataUpdated(assetId);
    }

    function getMetadata(bytes32 assetId) external view returns (Metadata memory) {
        return metadataRecords[assetId];
    }
}
