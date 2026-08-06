# ADR-SC-001

## Title

Protocol Access Control

## Status

Accepted

## Decision

Nebula shall use OpenZeppelin AccessControl as the canonical authorization framework.

Roles:

- DEFAULT_ADMIN_ROLE
- VALIDATOR_ROLE
- SELLER_ROLE
- BUYER_ROLE
- DISPUTE_ROLE

Every future contract shall inherit or reference this authorization layer.
