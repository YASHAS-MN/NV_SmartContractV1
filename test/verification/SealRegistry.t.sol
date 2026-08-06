// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/registry/AssetRegistry.sol";
import "../../src/verification/VerificationRegistry.sol";
import "../../src/verification/SealRegistry.sol";

contract SealRegistryTest is Test {
    AssetRegistry assetRegistry;
    VerificationRegistry verificationRegistry;
    SealRegistry sealRegistry;

    address owner = address(0x100);

    bytes32 assetHash = keccak256("asset_content");
    bytes32 transcriptHash = keccak256("transcript_data");
    bytes32 sandboxVersion = keccak256("sandbox_v1");
    bytes32 validatorSetHash = keccak256("validators_v1");
    bytes32 protocolVersion = keccak256("protocol_v1");

    bytes32 assetId;
    bytes32 verificationId;

    event SealCreated(bytes32 indexed sealId, bytes32 indexed verificationId, bytes32 indexed assetId);

    function setUp() public {
        assetRegistry = new AssetRegistry();
        verificationRegistry = new VerificationRegistry(address(assetRegistry));
        sealRegistry = new SealRegistry(address(verificationRegistry));

        vm.prank(owner);
        assetId = assetRegistry.registerAsset(assetHash);

        vm.prank(owner);
        verificationId = verificationRegistry.requestVerification(assetId, transcriptHash, sandboxVersion);
    }

    function testSuccessfulSealCreation() public {
        // Complete verification to VERIFIED status
        verificationRegistry.completeVerification(verificationId, VerificationRegistry.VerificationStatus.VERIFIED);

        bytes32 expectedSealId = keccak256(abi.encodePacked(verificationId, transcriptHash, block.timestamp));

        vm.expectEmit(true, true, true, false);
        emit SealCreated(expectedSealId, verificationId, assetId);

        bytes32 sealId = sealRegistry.createSeal(verificationId, validatorSetHash, protocolVersion);
        assertEq(sealId, expectedSealId);

        SealRegistry.VerificationSeal memory seal = sealRegistry.getSeal(sealId);
        assertTrue(seal.exists);
        assertEq(seal.sealId, sealId);
        assertEq(seal.verificationId, verificationId);
        assertEq(seal.assetId, assetId);
        assertEq(seal.transcriptHash, transcriptHash);
        assertEq(seal.sandboxVersion, sandboxVersion);
        assertEq(seal.protocolVersion, protocolVersion);
        assertEq(seal.validatorSetHash, validatorSetHash);
        assertEq(seal.sealedAt, uint64(block.timestamp));

        // Test getSealByVerification
        SealRegistry.VerificationSeal memory sealByVer = sealRegistry.getSealByVerification(verificationId);
        assertEq(sealByVer.sealId, sealId);
    }

    function testRejectNonVerifiedVerification() public {
        // Verification is still PENDING
        vm.expectRevert(SealRegistry.VerificationNotVerified.selector);
        sealRegistry.createSeal(verificationId, validatorSetHash, protocolVersion);

        // Complete as REJECTED
        verificationRegistry.completeVerification(verificationId, VerificationRegistry.VerificationStatus.REJECTED);

        vm.expectRevert(SealRegistry.VerificationNotVerified.selector);
        sealRegistry.createSeal(verificationId, validatorSetHash, protocolVersion);
    }

    function testRejectDuplicateSeal() public {
        verificationRegistry.completeVerification(verificationId, VerificationRegistry.VerificationStatus.VERIFIED);

        sealRegistry.createSeal(verificationId, validatorSetHash, protocolVersion);

        vm.expectRevert(SealRegistry.SealAlreadyExists.selector);
        sealRegistry.createSeal(verificationId, validatorSetHash, protocolVersion);
    }

    function testRejectZeroValidatorSetHash() public {
        verificationRegistry.completeVerification(verificationId, VerificationRegistry.VerificationStatus.VERIFIED);

        vm.expectRevert(SealRegistry.ZeroValidatorSetHash.selector);
        sealRegistry.createSeal(verificationId, bytes32(0), protocolVersion);
    }

    function testRejectZeroProtocolVersion() public {
        verificationRegistry.completeVerification(verificationId, VerificationRegistry.VerificationStatus.VERIFIED);

        vm.expectRevert(SealRegistry.ZeroProtocolVersion.selector);
        sealRegistry.createSeal(verificationId, validatorSetHash, bytes32(0));
    }

    function testGetterValidation() public {
        bytes32 dummyId = keccak256("dummy_seal");
        SealRegistry.VerificationSeal memory seal = sealRegistry.getSeal(dummyId);
        assertFalse(seal.exists);
        assertEq(seal.sealedAt, 0);

        SealRegistry.VerificationSeal memory sealByVer = sealRegistry.getSealByVerification(dummyId);
        assertFalse(sealByVer.exists);
    }
}
