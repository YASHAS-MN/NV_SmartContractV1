// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AssetRegistry} from "../registry/AssetRegistry.sol";

contract EscrowStateMachine {
    enum EscrowStatus {
        CREATED,
        FUNDED,
        DELIVERED,
        VERIFIED,
        DISPUTED,
        REFUNDED,
        COMPLETED,
        CANCELLED
    }

    struct Escrow {
        bool exists;
        bytes32 escrowId;
        bytes32 assetId;
        address seller;
        address buyer;
        EscrowStatus status;
        uint64 createdAt;
        uint64 updatedAt;
    }

    AssetRegistry public immutable assetRegistry;

    mapping(bytes32 => Escrow) private escrows;

    event EscrowCreated(bytes32 indexed escrowId);
    event EscrowStatusChanged(bytes32 indexed escrowId, EscrowStatus status);

    error ZeroAddress();
    error ZeroBuyerAddress();
    error InvalidBuyer();
    error AssetDoesNotExist();
    error AssetInactive();
    error NotAssetOwner();
    error EscrowDoesNotExist();
    error InvalidStateTransition();

    constructor(address _assetRegistry) {
        if (_assetRegistry == address(0)) {
            revert ZeroAddress();
        }
        assetRegistry = AssetRegistry(_assetRegistry);
    }

    function createEscrow(bytes32 assetId, address buyer) external returns (bytes32 escrowId) {
        if (buyer == address(0)) {
            revert ZeroBuyerAddress();
        }
        if (msg.sender == buyer) {
            revert InvalidBuyer();
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

        escrowId = keccak256(abi.encodePacked(assetId, msg.sender, buyer, block.timestamp));

        escrows[escrowId] = Escrow({
            exists: true,
            escrowId: escrowId,
            assetId: assetId,
            seller: msg.sender,
            buyer: buyer,
            status: EscrowStatus.CREATED,
            createdAt: uint64(block.timestamp),
            updatedAt: uint64(block.timestamp)
        });

        emit EscrowCreated(escrowId);
        emit EscrowStatusChanged(escrowId, EscrowStatus.CREATED);
    }

    function markFunded(bytes32 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        if (!escrow.exists) {
            revert EscrowDoesNotExist();
        }
        if (escrow.status != EscrowStatus.CREATED) {
            revert InvalidStateTransition();
        }

        escrow.status = EscrowStatus.FUNDED;
        escrow.updatedAt = uint64(block.timestamp);

        emit EscrowStatusChanged(escrowId, EscrowStatus.FUNDED);
    }

    function markDelivered(bytes32 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        if (!escrow.exists) {
            revert EscrowDoesNotExist();
        }
        if (escrow.status != EscrowStatus.FUNDED) {
            revert InvalidStateTransition();
        }

        escrow.status = EscrowStatus.DELIVERED;
        escrow.updatedAt = uint64(block.timestamp);

        emit EscrowStatusChanged(escrowId, EscrowStatus.DELIVERED);
    }

    function markVerified(bytes32 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        if (!escrow.exists) {
            revert EscrowDoesNotExist();
        }
        if (escrow.status != EscrowStatus.DELIVERED) {
            revert InvalidStateTransition();
        }

        escrow.status = EscrowStatus.VERIFIED;
        escrow.updatedAt = uint64(block.timestamp);

        emit EscrowStatusChanged(escrowId, EscrowStatus.VERIFIED);
    }

    function markDisputed(bytes32 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        if (!escrow.exists) {
            revert EscrowDoesNotExist();
        }
        if (escrow.status != EscrowStatus.DELIVERED) {
            revert InvalidStateTransition();
        }

        escrow.status = EscrowStatus.DISPUTED;
        escrow.updatedAt = uint64(block.timestamp);

        emit EscrowStatusChanged(escrowId, EscrowStatus.DISPUTED);
    }

    function markRefunded(bytes32 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        if (!escrow.exists) {
            revert EscrowDoesNotExist();
        }
        if (escrow.status != EscrowStatus.DISPUTED) {
            revert InvalidStateTransition();
        }

        escrow.status = EscrowStatus.REFUNDED;
        escrow.updatedAt = uint64(block.timestamp);

        emit EscrowStatusChanged(escrowId, EscrowStatus.REFUNDED);
    }

    function markCompleted(bytes32 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        if (!escrow.exists) {
            revert EscrowDoesNotExist();
        }
        if (escrow.status != EscrowStatus.VERIFIED) {
            revert InvalidStateTransition();
        }

        escrow.status = EscrowStatus.COMPLETED;
        escrow.updatedAt = uint64(block.timestamp);

        emit EscrowStatusChanged(escrowId, EscrowStatus.COMPLETED);
    }

    function cancelEscrow(bytes32 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        if (!escrow.exists) {
            revert EscrowDoesNotExist();
        }
        if (escrow.status != EscrowStatus.CREATED) {
            revert InvalidStateTransition();
        }

        escrow.status = EscrowStatus.CANCELLED;
        escrow.updatedAt = uint64(block.timestamp);

        emit EscrowStatusChanged(escrowId, EscrowStatus.CANCELLED);
    }

    function getEscrow(bytes32 escrowId) external view returns (Escrow memory) {
        return escrows[escrowId];
    }
}
