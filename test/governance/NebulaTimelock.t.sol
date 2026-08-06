// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/access/NebulaAccessControl.sol";
import "../../src/governance/NebulaTimelock.sol";

contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
}

contract NebulaTimelockTest is Test {
    NebulaAccessControl accessControl;
    NebulaTimelock timelock;
    MockTarget target;

    address admin = address(0x1);
    address nonAdmin = address(0x99);
    uint64 delay = 2 days;

    event OperationScheduled(bytes32 indexed operationId);
    event OperationExecuted(bytes32 indexed operationId);
    event OperationCancelled(bytes32 indexed operationId);

    function setUp() public {
        vm.startPrank(admin);
        accessControl = new NebulaAccessControl(admin);
        timelock = new NebulaTimelock(address(accessControl), delay);
        target = new MockTarget();
        vm.stopPrank();
    }

    function testScheduleOperation() public {
        bytes memory callData = abi.encodeWithSelector(MockTarget.setValue.selector, 42);

        vm.startPrank(admin);
        bytes32 expectedId = keccak256(abi.encode(address(target), callData, block.timestamp));

        vm.expectEmit(true, false, false, false);
        emit OperationScheduled(expectedId);

        bytes32 opId = timelock.scheduleOperation(address(target), callData);
        assertEq(opId, expectedId);
        vm.stopPrank();

        NebulaTimelock.Operation memory op = timelock.getOperation(opId);
        assertTrue(op.exists);
        assertFalse(op.executed);
        assertEq(op.target, address(target));
        assertEq(op.executeAfter, uint64(block.timestamp + delay));
    }

    function testExecuteAfterDelay() public {
        bytes memory callData = abi.encodeWithSelector(MockTarget.setValue.selector, 100);

        vm.prank(admin);
        bytes32 opId = timelock.scheduleOperation(address(target), callData);

        // Advance time past delay
        vm.warp(block.timestamp + delay + 1);

        vm.startPrank(admin);
        vm.expectEmit(true, false, false, false);
        emit OperationExecuted(opId);

        timelock.executeOperation(opId);
        vm.stopPrank();

        assertEq(target.value(), 100);
        assertTrue(timelock.getOperation(opId).executed);
    }

    function testExecuteBeforeDelayReverts() public {
        bytes memory callData = abi.encodeWithSelector(MockTarget.setValue.selector, 100);

        vm.prank(admin);
        bytes32 opId = timelock.scheduleOperation(address(target), callData);

        // Attempt execution immediately without warping time
        vm.prank(admin);
        vm.expectRevert(NebulaTimelock.OperationNotReady.selector);
        timelock.executeOperation(opId);
    }

    function testDuplicateExecutionReverts() public {
        bytes memory callData = abi.encodeWithSelector(MockTarget.setValue.selector, 100);

        vm.prank(admin);
        bytes32 opId = timelock.scheduleOperation(address(target), callData);

        vm.warp(block.timestamp + delay + 1);

        vm.startPrank(admin);
        timelock.executeOperation(opId);

        vm.expectRevert(NebulaTimelock.OperationAlreadyExecuted.selector);
        timelock.executeOperation(opId);
        vm.stopPrank();
    }

    function testCancelOperation() public {
        bytes memory callData = abi.encodeWithSelector(MockTarget.setValue.selector, 100);

        vm.prank(admin);
        bytes32 opId = timelock.scheduleOperation(address(target), callData);

        vm.startPrank(admin);
        vm.expectEmit(true, false, false, false);
        emit OperationCancelled(opId);

        timelock.cancelOperation(opId);
        vm.stopPrank();

        assertFalse(timelock.getOperation(opId).exists);
    }

    function testCancelExecutedOperationReverts() public {
        bytes memory callData = abi.encodeWithSelector(MockTarget.setValue.selector, 100);

        vm.prank(admin);
        bytes32 opId = timelock.scheduleOperation(address(target), callData);

        vm.warp(block.timestamp + delay + 1);

        vm.startPrank(admin);
        timelock.executeOperation(opId);

        vm.expectRevert(NebulaTimelock.OperationAlreadyExecuted.selector);
        timelock.cancelOperation(opId);
        vm.stopPrank();
    }

    function testUnauthorizedScheduleReverts() public {
        bytes memory callData = abi.encodeWithSelector(MockTarget.setValue.selector, 100);

        vm.prank(nonAdmin);
        vm.expectRevert(NebulaTimelock.NotAdmin.selector);
        timelock.scheduleOperation(address(target), callData);
    }

    function testGetterValidation() public {
        bytes32 dummyId = keccak256("dummy");
        NebulaTimelock.Operation memory op = timelock.getOperation(dummyId);
        assertFalse(op.exists);
        assertEq(op.executeAfter, 0);
    }
}
