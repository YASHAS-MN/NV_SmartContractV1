// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/registry/AssetRegistry.sol";
import "../../src/marketplace/EscrowStateMachine.sol";

contract EscrowStateMachineTest is Test {
    AssetRegistry assetRegistry;
    EscrowStateMachine escrowFSM;

    address seller = address(0x100);
    address buyer = address(0x200);

    bytes32 assetHash = keccak256("asset_content");
    bytes32 assetId;

    event EscrowCreated(bytes32 indexed escrowId);
    event EscrowStatusChanged(bytes32 indexed escrowId, EscrowStateMachine.EscrowStatus status);

    function setUp() public {
        assetRegistry = new AssetRegistry();
        escrowFSM = new EscrowStateMachine(address(assetRegistry));

        vm.prank(seller);
        assetId = assetRegistry.registerAsset(assetHash);
    }

    function testEscrowCreation() public {
        vm.startPrank(seller);

        bytes32 expectedEscrowId = keccak256(abi.encodePacked(assetId, seller, buyer, block.timestamp));

        vm.expectEmit(true, false, false, false);
        emit EscrowCreated(expectedEscrowId);

        bytes32 escrowId = escrowFSM.createEscrow(assetId, buyer);
        assertEq(escrowId, expectedEscrowId);
        vm.stopPrank();

        EscrowStateMachine.Escrow memory escrow = escrowFSM.getEscrow(escrowId);
        assertTrue(escrow.exists);
        assertEq(escrow.assetId, assetId);
        assertEq(escrow.seller, seller);
        assertEq(escrow.buyer, buyer);
        assertTrue(escrow.status == EscrowStateMachine.EscrowStatus.CREATED);
    }

    function testInvalidBuyerRejection() public {
        vm.startPrank(seller);

        vm.expectRevert(EscrowStateMachine.ZeroBuyerAddress.selector);
        escrowFSM.createEscrow(assetId, address(0));

        vm.expectRevert(EscrowStateMachine.InvalidBuyer.selector);
        escrowFSM.createEscrow(assetId, seller);

        vm.stopPrank();
    }

    function testValidTransitionPathHappyCase() public {
        vm.prank(seller);
        bytes32 escrowId = escrowFSM.createEscrow(assetId, buyer);

        // CREATED -> FUNDED
        vm.expectEmit(true, false, false, true);
        emit EscrowStatusChanged(escrowId, EscrowStateMachine.EscrowStatus.FUNDED);
        escrowFSM.markFunded(escrowId);
        assertTrue(escrowFSM.getEscrow(escrowId).status == EscrowStateMachine.EscrowStatus.FUNDED);

        // FUNDED -> DELIVERED
        vm.expectEmit(true, false, false, true);
        emit EscrowStatusChanged(escrowId, EscrowStateMachine.EscrowStatus.DELIVERED);
        escrowFSM.markDelivered(escrowId);
        assertTrue(escrowFSM.getEscrow(escrowId).status == EscrowStateMachine.EscrowStatus.DELIVERED);

        // DELIVERED -> VERIFIED
        vm.expectEmit(true, false, false, true);
        emit EscrowStatusChanged(escrowId, EscrowStateMachine.EscrowStatus.VERIFIED);
        escrowFSM.markVerified(escrowId);
        assertTrue(escrowFSM.getEscrow(escrowId).status == EscrowStateMachine.EscrowStatus.VERIFIED);

        // VERIFIED -> COMPLETED
        vm.expectEmit(true, false, false, true);
        emit EscrowStatusChanged(escrowId, EscrowStateMachine.EscrowStatus.COMPLETED);
        escrowFSM.markCompleted(escrowId);
        assertTrue(escrowFSM.getEscrow(escrowId).status == EscrowStateMachine.EscrowStatus.COMPLETED);
    }

    function testValidTransitionPathDisputeCase() public {
        vm.prank(seller);
        bytes32 escrowId = escrowFSM.createEscrow(assetId, buyer);

        escrowFSM.markFunded(escrowId);
        escrowFSM.markDelivered(escrowId);

        // DELIVERED -> DISPUTED
        vm.expectEmit(true, false, false, true);
        emit EscrowStatusChanged(escrowId, EscrowStateMachine.EscrowStatus.DISPUTED);
        escrowFSM.markDisputed(escrowId);
        assertTrue(escrowFSM.getEscrow(escrowId).status == EscrowStateMachine.EscrowStatus.DISPUTED);

        // DISPUTED -> REFUNDED
        vm.expectEmit(true, false, false, true);
        emit EscrowStatusChanged(escrowId, EscrowStateMachine.EscrowStatus.REFUNDED);
        escrowFSM.markRefunded(escrowId);
        assertTrue(escrowFSM.getEscrow(escrowId).status == EscrowStateMachine.EscrowStatus.REFUNDED);
    }

    function testValidTransitionPathCancellation() public {
        vm.prank(seller);
        bytes32 escrowId = escrowFSM.createEscrow(assetId, buyer);

        // CREATED -> CANCELLED
        vm.expectEmit(true, false, false, true);
        emit EscrowStatusChanged(escrowId, EscrowStateMachine.EscrowStatus.CANCELLED);
        escrowFSM.cancelEscrow(escrowId);
        assertTrue(escrowFSM.getEscrow(escrowId).status == EscrowStateMachine.EscrowStatus.CANCELLED);
    }

    function testInvalidTransitionReverts() public {
        vm.prank(seller);
        bytes32 escrowId = escrowFSM.createEscrow(assetId, buyer);

        // Cannot jump directly from CREATED to DELIVERED / VERIFIED / DISPUTED / REFUNDED / COMPLETED
        vm.expectRevert(EscrowStateMachine.InvalidStateTransition.selector);
        escrowFSM.markDelivered(escrowId);

        vm.expectRevert(EscrowStateMachine.InvalidStateTransition.selector);
        escrowFSM.markVerified(escrowId);

        vm.expectRevert(EscrowStateMachine.InvalidStateTransition.selector);
        escrowFSM.markDisputed(escrowId);

        vm.expectRevert(EscrowStateMachine.InvalidStateTransition.selector);
        escrowFSM.markRefunded(escrowId);

        vm.expectRevert(EscrowStateMachine.InvalidStateTransition.selector);
        escrowFSM.markCompleted(escrowId);
    }

    function testTerminalStateImmutability() public {
        vm.prank(seller);
        bytes32 escrowId1 = escrowFSM.createEscrow(assetId, buyer);

        // Reach CANCELLED terminal state
        escrowFSM.cancelEscrow(escrowId1);

        vm.expectRevert(EscrowStateMachine.InvalidStateTransition.selector);
        escrowFSM.markFunded(escrowId1);

        vm.expectRevert(EscrowStateMachine.InvalidStateTransition.selector);
        escrowFSM.cancelEscrow(escrowId1);

        // Reach COMPLETED terminal state
        vm.prank(seller);
        bytes32 escrowId2 = escrowFSM.createEscrow(assetId, buyer);
        escrowFSM.markFunded(escrowId2);
        escrowFSM.markDelivered(escrowId2);
        escrowFSM.markVerified(escrowId2);
        escrowFSM.markCompleted(escrowId2);

        vm.expectRevert(EscrowStateMachine.InvalidStateTransition.selector);
        escrowFSM.markVerified(escrowId2);

        vm.expectRevert(EscrowStateMachine.InvalidStateTransition.selector);
        escrowFSM.cancelEscrow(escrowId2);
    }

    function testGetterValidation() public {
        bytes32 dummyId = keccak256("dummy_escrow");
        EscrowStateMachine.Escrow memory escrow = escrowFSM.getEscrow(dummyId);
        assertFalse(escrow.exists);
        assertEq(escrow.createdAt, 0);
    }
}
