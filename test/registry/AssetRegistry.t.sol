// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/registry/AssetRegistry.sol";

contract AssetRegistryTest is Test {
    AssetRegistry registry;

    address owner1 = address(0x100);
    address owner2 = address(0x200);

    bytes32 hash1 = keccak256("asset_data_v1");
    bytes32 hash2 = keccak256("asset_data_v2");

    event AssetRegistered(bytes32 indexed assetId, address indexed owner);
    event OwnershipTransferred(bytes32 indexed assetId, address indexed from, address indexed to);
    event AssetVersionCreated(bytes32 indexed parentAssetId, bytes32 indexed newAssetId);
    event AssetArchived(bytes32 indexed assetId);

    function setUp() public {
        registry = new AssetRegistry();
    }

    function testAssetRegistration() public {
        vm.startPrank(owner1);

        bytes32 expectedAssetId = keccak256(abi.encodePacked(hash1, owner1, block.timestamp));

        vm.expectEmit(true, true, false, false);
        emit AssetRegistered(expectedAssetId, owner1);

        bytes32 assetId = registry.registerAsset(hash1);
        assertEq(assetId, expectedAssetId);

        vm.stopPrank();

        AssetRegistry.Asset memory asset = registry.getAsset(assetId);
        assertTrue(asset.exists);
        assertTrue(asset.active);
        assertEq(asset.assetHash, hash1);
        assertEq(asset.owner, owner1);
        assertEq(asset.version, 1);
        assertEq(asset.parentAssetId, bytes32(0));
        assertEq(asset.createdAt, uint64(block.timestamp));
    }

    function testZeroHashRejection() public {
        vm.prank(owner1);
        vm.expectRevert(AssetRegistry.ZeroAssetHash.selector);
        registry.registerAsset(bytes32(0));
    }

    function testOwnershipTransfer() public {
        vm.prank(owner1);
        bytes32 assetId = registry.registerAsset(hash1);

        vm.startPrank(owner1);
        vm.expectEmit(true, true, true, false);
        emit OwnershipTransferred(assetId, owner1, owner2);

        registry.transferOwnership(assetId, owner2);
        vm.stopPrank();

        AssetRegistry.Asset memory asset = registry.getAsset(assetId);
        assertEq(asset.owner, owner2);
    }

    function testUnauthorizedTransferReverts() public {
        vm.prank(owner1);
        bytes32 assetId = registry.registerAsset(hash1);

        vm.prank(owner2);
        vm.expectRevert(AssetRegistry.NotAssetOwner.selector);
        registry.transferOwnership(assetId, owner2);
    }

    function testVersionCreation() public {
        vm.startPrank(owner1);
        bytes32 parentAssetId = registry.registerAsset(hash1);

        // Advance time so newAssetId is unique
        vm.warp(block.timestamp + 10);

        bytes32 expectedNewAssetId = keccak256(abi.encodePacked(hash2, owner1, block.timestamp));

        vm.expectEmit(true, true, false, false);
        emit AssetVersionCreated(parentAssetId, expectedNewAssetId);

        bytes32 newAssetId = registry.createVersion(parentAssetId, hash2);
        assertEq(newAssetId, expectedNewAssetId);

        vm.stopPrank();

        // Check new version details
        AssetRegistry.Asset memory newAsset = registry.getAsset(newAssetId);
        assertTrue(newAsset.exists);
        assertTrue(newAsset.active);
        assertEq(newAsset.version, 2);
        assertEq(newAsset.parentAssetId, parentAssetId);

        // Check parent version immutability
        AssetRegistry.Asset memory parentAsset = registry.getAsset(parentAssetId);
        assertEq(parentAsset.version, 1);
    }

    function testArchive() public {
        vm.startPrank(owner1);
        bytes32 assetId = registry.registerAsset(hash1);

        vm.expectEmit(true, false, false, false);
        emit AssetArchived(assetId);

        registry.archiveAsset(assetId);
        vm.stopPrank();

        AssetRegistry.Asset memory asset = registry.getAsset(assetId);
        assertTrue(asset.exists);
        assertFalse(asset.active);

        // Archived asset operations should revert
        vm.startPrank(owner1);
        vm.expectRevert(AssetRegistry.AssetInactive.selector);
        registry.transferOwnership(assetId, owner2);

        vm.expectRevert(AssetRegistry.AssetInactive.selector);
        registry.createVersion(assetId, hash2);

        vm.expectRevert(AssetRegistry.AssetInactive.selector);
        registry.archiveAsset(assetId);
        vm.stopPrank();
    }

    function testGetterValidation() public {
        bytes32 dummyId = keccak256("non_existent");
        AssetRegistry.Asset memory asset = registry.getAsset(dummyId);
        assertFalse(asset.exists);
        assertFalse(asset.active);
        assertEq(asset.owner, address(0));
    }
}
