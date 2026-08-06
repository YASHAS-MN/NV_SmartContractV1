# ADR-SC-007

## Title

Consensus Precedes Sealing

## Status

Accepted

## Decision

- Validator agreement is a first-class protocol artifact.
- Verification is finalized only after quorum.
- SealRegistry shall only accept `ACCEPTED` consensus records.
