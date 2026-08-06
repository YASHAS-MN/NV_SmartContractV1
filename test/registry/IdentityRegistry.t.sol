// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/registry/IdentityRegistry.sol";

contract IdentityRegistryTest is Test {
    IdentityRegistry registry;

    address user1 = address(0x100);
    address user2 = address(0x200);

    bytes32 initialCID = keccak256("ipfs://initial");
    bytes32 updatedCID = keccak256("ipfs://updated");
    string initialEndpoint = "https://node1.nebula.io";
    string updatedEndpoint = "https://node2.nebula.io";

    event IdentityRegistered(address indexed account);
    event IdentityUpdated(address indexed account);
    event IdentityDeactivated(address indexed account);

    function setUp() public {
        registry = new IdentityRegistry();
    }

    function testSuccessfulRegistration() public {
        vm.startPrank(user1);

        vm.expectEmit(true, false, false, false);
        emit IdentityRegistered(user1);

        registry.register(initialCID, initialEndpoint);
        vm.stopPrank();

        IdentityRegistry.Identity memory id = registry.getIdentity(user1);
        assertTrue(id.exists);
        assertTrue(id.active);
        assertEq(id.metadataCID, initialCID);
        assertEq(id.nodeEndpoint, initialEndpoint);
        assertEq(id.joinedAt, uint64(block.timestamp));
    }

    function testDuplicateRegistrationReverts() public {
        vm.startPrank(user1);
        registry.register(initialCID, initialEndpoint);

        vm.expectRevert(IdentityRegistry.AlreadyRegistered.selector);
        registry.register(initialCID, initialEndpoint);
        vm.stopPrank();
    }

    function testMetadataUpdate() public {
        vm.startPrank(user1);
        registry.register(initialCID, initialEndpoint);

        vm.expectEmit(true, false, false, false);
        emit IdentityUpdated(user1);

        registry.updateMetadata(updatedCID);
        vm.stopPrank();

        IdentityRegistry.Identity memory id = registry.getIdentity(user1);
        assertEq(id.metadataCID, updatedCID);
    }

    function testEndpointUpdate() public {
        vm.startPrank(user1);
        registry.register(initialCID, initialEndpoint);

        vm.expectEmit(true, false, false, false);
        emit IdentityUpdated(user1);

        registry.updateEndpoint(updatedEndpoint);
        vm.stopPrank();

        IdentityRegistry.Identity memory id = registry.getIdentity(user1);
        assertEq(id.nodeEndpoint, updatedEndpoint);
    }

    function testUnauthorizedModificationReverts() public {
        // user2 has not registered
        vm.startPrank(user2);

        vm.expectRevert(IdentityRegistry.NotRegistered.selector);
        registry.updateMetadata(updatedCID);

        vm.expectRevert(IdentityRegistry.NotRegistered.selector);
        registry.updateEndpoint(updatedEndpoint);

        vm.expectRevert(IdentityRegistry.NotRegistered.selector);
        registry.deactivate();

        vm.stopPrank();
    }

    function testDeactivation() public {
        vm.startPrank(user1);
        registry.register(initialCID, initialEndpoint);

        vm.expectEmit(true, false, false, false);
        emit IdentityDeactivated(user1);

        registry.deactivate();

        IdentityRegistry.Identity memory id = registry.getIdentity(user1);
        assertFalse(id.active);
        assertTrue(id.exists);

        // Deactivated user cannot update or deactivate again
        vm.expectRevert(IdentityRegistry.IdentityInactive.selector);
        registry.updateMetadata(updatedCID);

        vm.expectRevert(IdentityRegistry.IdentityInactive.selector);
        registry.updateEndpoint(updatedEndpoint);

        vm.expectRevert(IdentityRegistry.IdentityInactive.selector);
        registry.deactivate();

        // Deactivated user cannot re-register (already exists)
        vm.expectRevert(IdentityRegistry.AlreadyRegistered.selector);
        registry.register(initialCID, initialEndpoint);

        vm.stopPrank();
    }

    function testGetterCorrectness() public {
        IdentityRegistry.Identity memory emptyId = registry.getIdentity(user1);
        assertFalse(emptyId.exists);
        assertFalse(emptyId.active);
        assertEq(emptyId.joinedAt, 0);

        vm.prank(user1);
        registry.register(initialCID, initialEndpoint);

        IdentityRegistry.Identity memory registeredId = registry.getIdentity(user1);
        assertTrue(registeredId.exists);
        assertTrue(registeredId.active);
    }
}
