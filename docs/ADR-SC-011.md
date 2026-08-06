# ADR-SC-011

## Title

Collateral Is Isolated

## Status

Accepted

## Decision

- Stake is held only inside `StakeVault`.
- No other contract may custody validator collateral.
- Slashing authority is delegated exclusively to `DISPUTE_ROLE`.
