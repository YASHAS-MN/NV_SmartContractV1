# ADR-SC-006

## Title

Verification Seals Are Immutable

## Status

Accepted

## Decision

- Every successful verification produces exactly one immutable seal.
- Seals reference transcript hashes but never store transcript contents.
- Seals are permanent protocol artifacts.
