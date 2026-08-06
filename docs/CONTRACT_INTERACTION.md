# Contract Interaction Guide — Backend & Integration Reference

## Executive Summary
This document provides the end-to-end integration workflow connecting Frontend, Sandbox, and Backend services with the **NebulaVerse Smart Contract v1.0** module.

---

## 1. High-Level System Architecture

```text
Frontend / Client Application

        │
        ▼
Marketplace Registry  (Listing Discovery & Selection)

        │
        ▼
   Escrow Swap        (Payment Lock & Secret Key Reveal Settlement)

        │
        ▼
   Stake Vault        (Validator Collateral & Dispute Bond Safeguard)

        │
        ▼
Consensus Registry    (Validator Quorum Voting & Verdict Consensus)

        │
        ▼
  Seal Registry       (Immutable Proof of Verification Issuance)
```

---

## 2. End-to-End Lifecycle Workflows

### 2.1 Participant Registration & Asset Onboarding
1. **Identity Registration**: Seller registers wallet identity via `IdentityRegistry.register(metadataCID, nodeEndpoint)`.
2. **Asset Minting**: Seller registers new asset hash via `AssetRegistry.registerAsset(assetHash)`.
3. **Metadata Mapping**: Off-chain IPFS metadata CID linked via `MetadataRegistry.registerMetadata(assetId, metadataCID, filenameHash, mimeTypeHash, fileSize)`.

### 2.2 Verification & Consensus Lifecycle
1. **Verification Request**: Requester calls `VerificationRegistry.requestVerification(assetId, transcriptHash, sandboxVersion)`.
2. **Validator Consensus**: Assigned validators submit votes via `ConsensusRegistry.vote(verificationId, verdict)`.
3. **Consensus Finalization**: Quorum reaches threshold; `ConsensusRegistry.finalizeConsensus(verificationId)` updates status to `ACCEPTED` or `REJECTED`.
4. **Verification Status Update**: `VerificationRegistry.completeVerification(verificationId, status)` updates status to `VERIFIED`.
5. **Seal Issuance**: Validator calls `SealRegistry.createSeal(verificationId, protocolVersion, validatorSetHash)` to produce an immutable `VerificationSeal`.

### 2.3 Marketplace Listing & Secret Reveal Settlement
1. **Create Listing**: Seller lists verified asset via `MarketplaceRegistry.createListing(assetId, verificationId, paymentToken, price)`.
2. **Escrow Creation**: Seller creates escrow agreement in `EscrowStateMachine.createEscrow(assetId, buyer)`.
3. **Lock Funds**: Buyer locks payment in `EscrowSwap.lockFunds(escrowId, paymentToken, amount, encryptedKeyHash)`.
4. **Secret Key Reveal**: Seller reveals secret key via `EscrowSwap.revealKey(escrowId, revealedKeyHash)`.
5. **Atomic Settlement**: Client calls `EscrowSwap.settle(escrowId)`:
   - Validates `keccak256(revealedKeyHash) == encryptedKeyHash`.
   - Transfers payment token to seller.
   - Advances `EscrowStateMachine` status (`FUNDED` -> `DELIVERED` -> `VERIFIED` -> `COMPLETED`).
   - Marks listing as `SOLD` in `MarketplaceRegistry`.

### 2.4 Dispute & Refund Lifecycle
1. **Trigger Refund**: If secret reveal fails or hash mismatches, caller invokes `EscrowSwap.refund(escrowId)`.
2. **Escrow Status**: `EscrowStateMachine` updates status to `DISPUTED` then `REFUNDED`.
3. **Token Refund**: Locked payment token is safely returned to buyer.
4. **Dispute Logging**: Dispute authority updates validator records via `ReputationLedger.recordFailedDispute` and slashes collateral in `StakeVault.slashStake` if malicious behavior occurred.

---

## 3. ABI Integration Coordinates

| Contract | Core Entry Points | Key Events |
| :--- | :--- | :--- |
| `NebulaAccessControl` | `grantValidator`, `grantSeller`, `grantBuyer`, `grantDispute` | `RoleGranted`, `RoleRevoked` |
| `IdentityRegistry` | `register`, `updateMetadata`, `updateEndpoint`, `deactivate` | `IdentityRegistered`, `IdentityUpdated` |
| `AssetRegistry` | `registerAsset`, `createVersion`, `transferOwnership`, `archive` | `AssetRegistered`, `OwnershipTransferred` |
| `MetadataRegistry` | `registerMetadata`, `updateMetadata` | `MetadataRegistered`, `MetadataUpdated` |
| `VerificationRegistry`| `requestVerification`, `completeVerification` | `VerificationRequested`, `VerificationCompleted` |
| `ConsensusRegistry` | `vote`, `finalizeConsensus` | `VoteCast`, `ConsensusFinalized` |
| `SealRegistry` | `createSeal` | `SealCreated` |
| `EscrowStateMachine` | `createEscrow`, `markFunded`, `markDelivered`, `markCompleted` | `EscrowCreated`, `EscrowStatusUpdated` |
| `EscrowSwap` | `lockFunds`, `revealKey`, `settle`, `refund` | `FundsLocked`, `KeyRevealed`, `EscrowSettled` |
| `MarketplaceRegistry` | `createListing`, `updatePrice`, `markSold`, `delist` | `ListingCreated`, `ListingSold` |
| `StakeVault` | `depositStake`, `lockStake`, `releaseStake`, `slashStake` | `StakeDeposited`, `StakeLocked`, `StakeSlashed` |
| `ReputationLedger` | `recordVerification`, `recordSuccessfulDispute`, `recordSlash` | `VerificationRecorded`, `SlashRecorded` |
| `ParameterRegistry` | `setMinimumStake`, `setMarketplaceFee`, `setDisputeWindow` | `MinimumStakeUpdated`, `MarketplaceFeeUpdated` |
| `EmergencyPause` | `pause`, `unpause` | `EmergencyPaused`, `EmergencyResumed` |
| `NebulaTimelock` | `scheduleOperation`, `executeOperation`, `cancelOperation` | `OperationScheduled`, `OperationExecuted` |
