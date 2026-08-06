// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/registry/AssetRegistry.sol";
import "../../src/verification/VerificationRegistry.sol";

contract VerificationRegistryTest is Test {
    AssetRegistry assetRegistry;
    VerificationRegistry verificationRegistry;

    address owner = address(0x100);
    address nonOwner = address(0x200);

    bytes32 assetHash = keccak256("asset_content");
    bytes32 transcriptHash = keccak256("transcript_data");
    bytes32 sandboxVersion = keccak256("v1.0.0");

    bytes32 assetId;

    event VerificationRequested(bytes32 indexed verificationId, bytes32 indexed assetId);
    event VerificationCompleted(bytes32 indexed verificationId, VerificationRegistry.VerificationStatus status);
    event VerificationDisputed(bytes32 indexed verificationId);

    function setUp() public {
        assetRegistry = new AssetRegistry();
        verificationRegistry = new VerificationRegistry(address(assetRegistry));

        vm.prank(owner);
        assetId = assetRegistry.registerAsset(assetHash);
    }

    function testSuccessfulVerificationRequest() public {
        vm.startPrank(owner);

        bytes32 expectedVerificationId = keccak256(abi.encodePacked(assetId, transcriptHash, owner, block.timestamp));

        vm.expectEmit(true, true, false, false);
        emit VerificationRequested(expectedVerificationId, assetId);

        bytes32 verificationId = verificationRegistry.requestVerification(assetId, transcriptHash, sandboxVersion);
        assertEq(verificationId, expectedVerificationId);
        vm.stopPrank();

        VerificationRegistry.Verification memory v = verificationRegistry.getVerification(verificationId);
        assertTrue(v.exists);
        assertEq(v.verificationId, verificationId);
        assertEq(v.assetId, assetId);
        assertEq(v.transcriptHash, transcriptHash);
        assertEq(v.sandboxVersion, sandboxVersion);
        assertEq(v.requester, owner);
        assertTrue(v.status == VerificationRegistry.VerificationStatus.PENDING);
        assertEq(v.createdAt, uint64(block.timestamp));
        assertEq(v.completedAt, 0);
    }

    function testNonOwnerRequestReverts() public {
        vm.prank(nonOwner);
        vm.expectRevert(VerificationRegistry.NotAssetOwner.selector);
        verificationRegistry.requestVerification(assetId, transcriptHash, sandboxVersion);
    }

    function testZeroTranscriptHashRejected() public {
        vm.prank(owner);
        vm.expectRevert(VerificationRegistry.ZeroTranscriptHash.selector);
        verificationRegistry.requestVerification(assetId, bytes32(0), sandboxVersion);
    }

    function testZeroSandboxVersionRejected() public {
        vm.prank(owner);
        vm.expectRevert(VerificationRegistry.ZeroSandboxVersion.selector);
        verificationRegistry.requestVerification(assetId, transcriptHash, bytes32(0));
    }

    function testSuccessfulCompletion() public {
        vm.prank(owner);
        bytes32 verificationId = verificationRegistry.requestVerification(assetId, transcriptHash, sandboxVersion);

        vm.expectEmit(true, false, false, true);
        emit VerificationCompleted(verificationId, VerificationRegistry.VerificationStatus.VERIFIED);

        verificationRegistry.completeVerification(verificationId, VerificationRegistry.VerificationStatus.VERIFIED);

        VerificationRegistry.Verification memory v = verificationRegistry.getVerification(verificationId);
        assertTrue(v.status == VerificationRegistry.VerificationStatus.VERIFIED);
        assertEq(v.completedAt, uint64(block.timestamp));
    }

    function testDoubleCompletionReverts() public {
        vm.prank(owner);
        bytes32 verificationId = verificationRegistry.requestVerification(assetId, transcriptHash, sandboxVersion);

        verificationRegistry.completeVerification(verificationId, VerificationRegistry.VerificationStatus.VERIFIED);

        vm.expectRevert(VerificationRegistry.InvalidStatusTransition.selector);
        verificationRegistry.completeVerification(verificationId, VerificationRegistry.VerificationStatus.REJECTED);
    }

    function testDisputeTransition() public {
        vm.prank(owner);
        bytes32 verificationId = verificationRegistry.requestVerification(assetId, transcriptHash, sandboxVersion);

        // Cannot dispute while PENDING
        vm.expectRevert(VerificationRegistry.InvalidStatusTransition.selector);
        verificationRegistry.markDisputed(verificationId);

        // Complete first
        verificationRegistry.completeVerification(verificationId, VerificationRegistry.VerificationStatus.VERIFIED);

        // Now dispute
        vm.expectEmit(true, false, false, false);
        emit VerificationDisputed(verificationId);

        verificationRegistry.markDisputed(verificationId);

        VerificationRegistry.Verification memory v = verificationRegistry.getVerification(verificationId);
        assertTrue(v.status == VerificationRegistry.VerificationStatus.DISPUTED);
    }

    function testGetterValidation() public {
        bytes32 dummyId = keccak256("dummy_verification");
        VerificationRegistry.Verification memory v = verificationRegistry.getVerification(dummyId);
        assertFalse(v.exists);
        assertEq(v.createdAt, 0);
    }
}
