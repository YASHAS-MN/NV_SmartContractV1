// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract AssetRegistry {
    struct Asset {
        bool exists;
        bytes32 assetHash;
        address owner;
        uint256 version;
        bytes32 parentAssetId;
        uint64 createdAt;
        bool active;
    }

    mapping(bytes32 => Asset) private assets;

    event AssetRegistered(bytes32 indexed assetId, address indexed owner);
    event OwnershipTransferred(bytes32 indexed assetId, address indexed from, address indexed to);
    event AssetVersionCreated(bytes32 indexed parentAssetId, bytes32 indexed newAssetId);
    event AssetArchived(bytes32 indexed assetId);

    error ZeroAssetHash();
    error ZeroAddress();
    error AssetDoesNotExist();
    error AssetInactive();
    error NotAssetOwner();

    function registerAsset(bytes32 assetHash) external returns (bytes32 assetId) {
        if (assetHash == bytes32(0)) {
            revert ZeroAssetHash();
        }

        assetId = keccak256(abi.encodePacked(assetHash, msg.sender, block.timestamp));

        assets[assetId] = Asset({
            exists: true,
            assetHash: assetHash,
            owner: msg.sender,
            version: 1,
            parentAssetId: bytes32(0),
            createdAt: uint64(block.timestamp),
            active: true
        });

        emit AssetRegistered(assetId, msg.sender);
    }

    function transferOwnership(bytes32 assetId, address newOwner) external {
        if (newOwner == address(0)) {
            revert ZeroAddress();
        }

        Asset storage asset = assets[assetId];
        if (!asset.exists) {
            revert AssetDoesNotExist();
        }
        if (!asset.active) {
            revert AssetInactive();
        }
        if (msg.sender != asset.owner) {
            revert NotAssetOwner();
        }

        address previousOwner = asset.owner;
        asset.owner = newOwner;

        emit OwnershipTransferred(assetId, previousOwner, newOwner);
    }

    function createVersion(bytes32 parentAssetId, bytes32 assetHash) external returns (bytes32 newAssetId) {
        if (assetHash == bytes32(0)) {
            revert ZeroAssetHash();
        }

        Asset storage parentAsset = assets[parentAssetId];
        if (!parentAsset.exists) {
            revert AssetDoesNotExist();
        }
        if (!parentAsset.active) {
            revert AssetInactive();
        }
        if (msg.sender != parentAsset.owner) {
            revert NotAssetOwner();
        }

        newAssetId = keccak256(abi.encodePacked(assetHash, msg.sender, block.timestamp));

        assets[newAssetId] = Asset({
            exists: true,
            assetHash: assetHash,
            owner: msg.sender,
            version: parentAsset.version + 1,
            parentAssetId: parentAssetId,
            createdAt: uint64(block.timestamp),
            active: true
        });

        emit AssetVersionCreated(parentAssetId, newAssetId);
        emit AssetRegistered(newAssetId, msg.sender);
    }

    function archiveAsset(bytes32 assetId) external {
        Asset storage asset = assets[assetId];
        if (!asset.exists) {
            revert AssetDoesNotExist();
        }
        if (!asset.active) {
            revert AssetInactive();
        }
        if (msg.sender != asset.owner) {
            revert NotAssetOwner();
        }

        asset.active = false;

        emit AssetArchived(assetId);
    }

    function getAsset(bytes32 assetId) external view returns (Asset memory) {
        return assets[assetId];
    }
}
