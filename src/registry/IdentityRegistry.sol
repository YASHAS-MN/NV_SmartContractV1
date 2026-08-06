// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract IdentityRegistry {
    struct Identity {
        bool exists;
        bool active;
        string nodeEndpoint;
        bytes32 metadataCID;
        uint64 joinedAt;
    }

    mapping(address => Identity) private identities;

    event IdentityRegistered(address indexed account);
    event IdentityUpdated(address indexed account);
    event IdentityDeactivated(address indexed account);

    error AlreadyRegistered();
    error NotRegistered();
    error IdentityInactive();

    function register(bytes32 metadataCID, string calldata nodeEndpoint) external {
        if (identities[msg.sender].exists) {
            revert AlreadyRegistered();
        }

        identities[msg.sender] = Identity({
            exists: true,
            active: true,
            nodeEndpoint: nodeEndpoint,
            metadataCID: metadataCID,
            joinedAt: uint64(block.timestamp)
        });

        emit IdentityRegistered(msg.sender);
    }

    function updateMetadata(bytes32 metadataCID) external {
        Identity storage identity = identities[msg.sender];
        if (!identity.exists) {
            revert NotRegistered();
        }
        if (!identity.active) {
            revert IdentityInactive();
        }

        identity.metadataCID = metadataCID;
        emit IdentityUpdated(msg.sender);
    }

    function updateEndpoint(string calldata endpoint) external {
        Identity storage identity = identities[msg.sender];
        if (!identity.exists) {
            revert NotRegistered();
        }
        if (!identity.active) {
            revert IdentityInactive();
        }

        identity.nodeEndpoint = endpoint;
        emit IdentityUpdated(msg.sender);
    }

    function deactivate() external {
        Identity storage identity = identities[msg.sender];
        if (!identity.exists) {
            revert NotRegistered();
        }
        if (!identity.active) {
            revert IdentityInactive();
        }

        identity.active = false;
        emit IdentityDeactivated(msg.sender);
    }

    function getIdentity(address account) external view returns (Identity memory) {
        return identities[account];
    }
}
