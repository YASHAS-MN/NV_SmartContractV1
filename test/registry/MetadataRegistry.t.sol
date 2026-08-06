// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/registry/AssetRegistry.sol";
import "../../src/registry/MetadataRegistry.sol";

contract MetadataRegistryTest is Test {
    AssetRegistry assetRegistry;
    MetadataRegistry metadataRegistry;

    address owner = address(0x100);
    address nonOwner = address(0x200);

    bytes32 assetHash = keccak256("asset_content");
    bytes32 metadataCID1 = keccak256("ipfs://cid1");
    bytes32 metadataCID2 = keccak256("ipfs://cid2");
    bytes32 filenameHash = keccak256("file.json");
    bytes32 mimeTypeHash = keccak256("application/json");
    uint256 fileSize = 2048;

    bytes32 assetId;

    event MetadataRegistered(bytes32 indexed assetId);
    event MetadataUpdated(bytes32 indexed assetId);

    function setUp() public {
        assetRegistry = new AssetRegistry();
        metadataRegistry = new MetadataRegistry(address(assetRegistry));

        vm.prank(owner);
        assetId = assetRegistry.registerAsset(assetHash);
    }

    function testMetadataRegistration() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, false);
        emit MetadataRegistered(assetId);

        metadataRegistry.registerMetadata(assetId, metadataCID1, filenameHash, mimeTypeHash, fileSize);
        vm.stopPrank();

        MetadataRegistry.Metadata memory meta = metadataRegistry.getMetadata(assetId);
        assertTrue(meta.exists);
        assertEq(meta.assetId, assetId);
        assertEq(meta.metadataCID, metadataCID1);
        assertEq(meta.filenameHash, filenameHash);
        assertEq(meta.mimeTypeHash, mimeTypeHash);
        assertEq(meta.fileSize, fileSize);
        assertEq(meta.registeredAt, uint64(block.timestamp));
    }

    function testDuplicateRegistrationReverts() public {
        vm.startPrank(owner);
        metadataRegistry.registerMetadata(assetId, metadataCID1, filenameHash, mimeTypeHash, fileSize);

        vm.expectRevert(MetadataRegistry.MetadataAlreadyExists.selector);
        metadataRegistry.registerMetadata(assetId, metadataCID2, filenameHash, mimeTypeHash, fileSize);
        vm.stopPrank();
    }

    function testZeroCIDRejected() public {
        vm.startPrank(owner);
        vm.expectRevert(MetadataRegistry.ZeroMetadataCID.selector);
        metadataRegistry.registerMetadata(assetId, bytes32(0), filenameHash, mimeTypeHash, fileSize);

        // Register valid metadata first to test update zero CID
        metadataRegistry.registerMetadata(assetId, metadataCID1, filenameHash, mimeTypeHash, fileSize);

        vm.expectRevert(MetadataRegistry.ZeroMetadataCID.selector);
        metadataRegistry.updateMetadata(assetId, bytes32(0));
        vm.stopPrank();
    }

    function testZeroFilesizeRejected() public {
        vm.prank(owner);
        vm.expectRevert(MetadataRegistry.ZeroFileSize.selector);
        metadataRegistry.registerMetadata(assetId, metadataCID1, filenameHash, mimeTypeHash, 0);
    }

    function testUnauthorizedUpdateReverts() public {
        vm.prank(owner);
        metadataRegistry.registerMetadata(assetId, metadataCID1, filenameHash, mimeTypeHash, fileSize);

        vm.prank(nonOwner);
        vm.expectRevert(MetadataRegistry.NotAssetOwner.selector);
        metadataRegistry.updateMetadata(assetId, metadataCID2);
    }

    function testMetadataUpdate() public {
        vm.startPrank(owner);
        metadataRegistry.registerMetadata(assetId, metadataCID1, filenameHash, mimeTypeHash, fileSize);

        vm.expectEmit(true, false, false, false);
        emit MetadataUpdated(assetId);

        metadataRegistry.updateMetadata(assetId, metadataCID2);
        vm.stopPrank();

        MetadataRegistry.Metadata memory meta = metadataRegistry.getMetadata(assetId);
        assertEq(meta.metadataCID, metadataCID2);
    }

    function testGetterValidation() public {
        bytes32 unusedId = keccak256("unused_asset_id");
        MetadataRegistry.Metadata memory meta = metadataRegistry.getMetadata(unusedId);
        assertFalse(meta.exists);
        assertEq(meta.fileSize, 0);
    }
}
