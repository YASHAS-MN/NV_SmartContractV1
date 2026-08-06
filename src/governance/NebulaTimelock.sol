// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NebulaAccessControl} from "../access/NebulaAccessControl.sol";

contract NebulaTimelock {
    struct Operation {
        bool exists;
        bool executed;
        bytes32 operationId;
        address target;
        bytes data;
        uint64 executeAfter;
    }

    NebulaAccessControl public immutable accessControl;
    uint64 public immutable minimumDelay;

    mapping(bytes32 => Operation) private operations;

    event OperationScheduled(bytes32 indexed operationId);
    event OperationExecuted(bytes32 indexed operationId);
    event OperationCancelled(bytes32 indexed operationId);

    error ZeroAddress();
    error InvalidMinimumDelay();
    error ZeroTargetAddress();
    error OperationAlreadyExists();
    error OperationDoesNotExist();
    error OperationAlreadyExecuted();
    error OperationNotReady();
    error OperationExecutionFailed();
    error NotAdmin();

    constructor(address _accessControl, uint64 _minimumDelay) {
        if (_accessControl == address(0)) {
            revert ZeroAddress();
        }
        if (_minimumDelay == 0) {
            revert InvalidMinimumDelay();
        }
        accessControl = NebulaAccessControl(_accessControl);
        minimumDelay = _minimumDelay;
    }

    function scheduleOperation(address target, bytes calldata data) external returns (bytes32 operationId) {
        _checkAdmin();
        if (target == address(0)) {
            revert ZeroTargetAddress();
        }

        operationId = keccak256(abi.encode(target, data, block.timestamp));
        if (operations[operationId].exists) {
            revert OperationAlreadyExists();
        }

        uint64 executeAfter = uint64(block.timestamp + minimumDelay);

        operations[operationId] = Operation({
            exists: true,
            executed: false,
            operationId: operationId,
            target: target,
            data: data,
            executeAfter: executeAfter
        });

        emit OperationScheduled(operationId);
    }

    function executeOperation(bytes32 operationId) external {
        _checkAdmin();

        Operation storage op = operations[operationId];
        if (!op.exists) {
            revert OperationDoesNotExist();
        }
        if (op.executed) {
            revert OperationAlreadyExecuted();
        }
        if (block.timestamp < op.executeAfter) {
            revert OperationNotReady();
        }

        op.executed = true;

        (bool success,) = op.target.call(op.data);
        if (!success) {
            revert OperationExecutionFailed();
        }

        emit OperationExecuted(operationId);
    }

    function cancelOperation(bytes32 operationId) external {
        _checkAdmin();

        Operation storage op = operations[operationId];
        if (!op.exists) {
            revert OperationDoesNotExist();
        }
        if (op.executed) {
            revert OperationAlreadyExecuted();
        }

        delete operations[operationId];

        emit OperationCancelled(operationId);
    }

    function getOperation(bytes32 operationId) external view returns (Operation memory) {
        return operations[operationId];
    }

    function _checkAdmin() private view {
        if (!accessControl.hasRole(accessControl.DEFAULT_ADMIN_ROLE(), msg.sender)) {
            revert NotAdmin();
        }
    }
}
