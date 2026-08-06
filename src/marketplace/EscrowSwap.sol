// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EscrowStateMachine} from "./EscrowStateMachine.sol";
import {EmergencyPause} from "../security/EmergencyPause.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract EscrowSwap is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct EscrowAgreement {
        bool exists;
        bytes32 escrowId;
        bytes32 assetId;
        address seller;
        address buyer;
        address paymentToken;
        uint256 amount;
        bytes32 encryptedKeyHash;
        bytes32 revealedKeyHash;
        bool settled;
    }

    EscrowStateMachine public immutable escrowStateMachine;
    EmergencyPause public immutable emergencyPause;

    mapping(bytes32 => EscrowAgreement) private agreements;

    event FundsLocked(bytes32 indexed escrowId, address indexed buyer, uint256 amount);
    event KeyRevealed(bytes32 indexed escrowId);
    event EscrowSettled(bytes32 indexed escrowId);
    event EscrowRefunded(bytes32 indexed escrowId);

    error ZeroAddress();
    error ZeroPaymentToken();
    error ZeroAmount();
    error ZeroKeyHash();
    error EscrowDoesNotExist();
    error NotBuyer();
    error NotSeller();
    error AlreadyLocked();
    error AlreadyRevealed();
    error AlreadySettled();
    error KeyHashMismatch();
    error KeyNotRevealed();
    error KeyHashMatchedCannotRefund();
    error InvalidEscrowState();
    error ProtocolPaused();

    constructor(address _escrowStateMachine, address _emergencyPause) {
        if (_escrowStateMachine == address(0) || _emergencyPause == address(0)) {
            revert ZeroAddress();
        }
        escrowStateMachine = EscrowStateMachine(_escrowStateMachine);
        emergencyPause = EmergencyPause(_emergencyPause);
    }

    modifier whenNotPaused() {
        if (emergencyPause.paused()) {
            revert ProtocolPaused();
        }
        _;
    }

    function lockFunds(bytes32 escrowId, address paymentToken, uint256 amount, bytes32 encryptedKeyHash)
        external
        nonReentrant
        whenNotPaused
    {
        if (paymentToken == address(0)) {
            revert ZeroPaymentToken();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (encryptedKeyHash == bytes32(0)) {
            revert ZeroKeyHash();
        }
        if (agreements[escrowId].exists) {
            revert AlreadyLocked();
        }

        EscrowStateMachine.Escrow memory escrow = escrowStateMachine.getEscrow(escrowId);
        if (!escrow.exists) {
            revert EscrowDoesNotExist();
        }
        if (msg.sender != escrow.buyer) {
            revert NotBuyer();
        }
        if (escrow.status != EscrowStateMachine.EscrowStatus.CREATED) {
            revert InvalidEscrowState();
        }

        agreements[escrowId] = EscrowAgreement({
            exists: true,
            escrowId: escrowId,
            assetId: escrow.assetId,
            seller: escrow.seller,
            buyer: escrow.buyer,
            paymentToken: paymentToken,
            amount: amount,
            encryptedKeyHash: encryptedKeyHash,
            revealedKeyHash: bytes32(0),
            settled: false
        });

        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);
        escrowStateMachine.markFunded(escrowId);

        emit FundsLocked(escrowId, msg.sender, amount);
    }

    function revealKey(bytes32 escrowId, bytes32 revealedKeyHash) external whenNotPaused {
        EscrowAgreement storage agreement = agreements[escrowId];
        if (!agreement.exists) {
            revert EscrowDoesNotExist();
        }
        if (msg.sender != agreement.seller) {
            revert NotSeller();
        }
        if (agreement.settled) {
            revert AlreadySettled();
        }
        if (revealedKeyHash == bytes32(0)) {
            revert ZeroKeyHash();
        }
        if (agreement.revealedKeyHash != bytes32(0)) {
            revert AlreadyRevealed();
        }

        agreement.revealedKeyHash = revealedKeyHash;

        emit KeyRevealed(escrowId);
    }

    function settle(bytes32 escrowId) external nonReentrant whenNotPaused {
        EscrowAgreement storage agreement = agreements[escrowId];
        if (!agreement.exists) {
            revert EscrowDoesNotExist();
        }
        if (agreement.settled) {
            revert AlreadySettled();
        }
        if (agreement.revealedKeyHash == bytes32(0)) {
            revert KeyNotRevealed();
        }
        if (keccak256(abi.encodePacked(agreement.revealedKeyHash)) != agreement.encryptedKeyHash) {
            revert KeyHashMismatch();
        }

        agreement.settled = true;

        escrowStateMachine.markDelivered(escrowId);
        escrowStateMachine.markVerified(escrowId);
        escrowStateMachine.markCompleted(escrowId);

        IERC20(agreement.paymentToken).safeTransfer(agreement.seller, agreement.amount);

        emit EscrowSettled(escrowId);
    }

    function refund(bytes32 escrowId) external nonReentrant whenNotPaused {
        EscrowAgreement storage agreement = agreements[escrowId];
        if (!agreement.exists) {
            revert EscrowDoesNotExist();
        }
        if (agreement.settled) {
            revert AlreadySettled();
        }

        if (
            agreement.revealedKeyHash != bytes32(0)
                && keccak256(abi.encodePacked(agreement.revealedKeyHash)) == agreement.encryptedKeyHash
        ) {
            revert KeyHashMatchedCannotRefund();
        }

        agreement.settled = true;

        EscrowStateMachine.Escrow memory escrow = escrowStateMachine.getEscrow(escrowId);
        if (escrow.status == EscrowStateMachine.EscrowStatus.FUNDED) {
            escrowStateMachine.markDelivered(escrowId);
            escrowStateMachine.markDisputed(escrowId);
            escrowStateMachine.markRefunded(escrowId);
        }

        IERC20(agreement.paymentToken).safeTransfer(agreement.buyer, agreement.amount);

        emit EscrowRefunded(escrowId);
    }

    function getAgreement(bytes32 escrowId) external view returns (EscrowAgreement memory) {
        return agreements[escrowId];
    }
}
