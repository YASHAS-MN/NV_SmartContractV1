// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract NebulaAccessControl is AccessControl {
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant SELLER_ROLE = keccak256("SELLER_ROLE");
    bytes32 public constant BUYER_ROLE = keccak256("BUYER_ROLE");
    bytes32 public constant DISPUTE_ROLE = keccak256("DISPUTE_ROLE");

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function grantValidator(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(VALIDATOR_ROLE, account);
    }

    function revokeValidator(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(VALIDATOR_ROLE, account);
    }

    function grantSeller(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(SELLER_ROLE, account);
    }

    function revokeSeller(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(SELLER_ROLE, account);
    }

    function grantBuyer(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BUYER_ROLE, account);
    }

    function revokeBuyer(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(BUYER_ROLE, account);
    }

    function grantDispute(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(DISPUTE_ROLE, account);
    }

    function revokeDispute(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(DISPUTE_ROLE, account);
    }
}
