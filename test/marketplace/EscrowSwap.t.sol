// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/registry/AssetRegistry.sol";
import "../../src/marketplace/EscrowStateMachine.sol";
import "../../src/marketplace/EscrowSwap.sol";

import "../../src/security/EmergencyPause.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract EscrowSwapTest is Test {
    AssetRegistry assetRegistry;
    EscrowStateMachine escrowFSM;
    EscrowSwap escrowSwap;
    EmergencyPause emergencyPause;
    MockERC20 token;

    address seller = address(0x100);
    address buyer = address(0x200);
    address intruder = address(0x999);

    bytes32 assetHash = keccak256("asset_data");
    bytes32 secretKey = keccak256("secret_key_123");
    bytes32 encryptedKeyHash = keccak256(abi.encodePacked(secretKey));
    bytes32 wrongKeyHash = keccak256("wrong_key_456");

    bytes32 assetId;
    bytes32 escrowId;
    uint256 amount = 1000 * 10 ** 18;

    event FundsLocked(bytes32 indexed escrowId, address indexed buyer, uint256 amount);
    event KeyRevealed(bytes32 indexed escrowId);
    event EscrowSettled(bytes32 indexed escrowId);
    event EscrowRefunded(bytes32 indexed escrowId);

    function setUp() public {
        assetRegistry = new AssetRegistry();
        escrowFSM = new EscrowStateMachine(address(assetRegistry));
        emergencyPause = new EmergencyPause(address(this));
        escrowSwap = new EscrowSwap(address(escrowFSM), address(emergencyPause));
        token = new MockERC20();

        // Mint tokens to buyer
        token.mint(buyer, amount * 10);

        // Register asset by seller
        vm.prank(seller);
        assetId = assetRegistry.registerAsset(assetHash);

        // Create escrow by seller
        vm.prank(seller);
        escrowId = escrowFSM.createEscrow(assetId, buyer);

        // Approve token transfer by buyer
        vm.prank(buyer);
        token.approve(address(escrowSwap), amount * 10);
    }

    function testLockFunds() public {
        vm.startPrank(buyer);
        vm.expectEmit(true, true, false, true);
        emit FundsLocked(escrowId, buyer, amount);

        escrowSwap.lockFunds(escrowId, address(token), amount, encryptedKeyHash);
        vm.stopPrank();

        EscrowSwap.EscrowAgreement memory agreement = escrowSwap.getAgreement(escrowId);
        assertTrue(agreement.exists);
        assertEq(agreement.amount, amount);
        assertEq(agreement.paymentToken, address(token));
        assertEq(agreement.encryptedKeyHash, encryptedKeyHash);
        assertEq(token.balanceOf(address(escrowSwap)), amount);

        // State machine status updated to FUNDED
        assertTrue(escrowFSM.getEscrow(escrowId).status == EscrowStateMachine.EscrowStatus.FUNDED);
    }

    function testZeroAmountRejection() public {
        vm.prank(buyer);
        vm.expectRevert(EscrowSwap.ZeroAmount.selector);
        escrowSwap.lockFunds(escrowId, address(token), 0, encryptedKeyHash);
    }

    function testZeroTokenRejection() public {
        vm.prank(buyer);
        vm.expectRevert(EscrowSwap.ZeroPaymentToken.selector);
        escrowSwap.lockFunds(escrowId, address(0), amount, encryptedKeyHash);
    }

    function testUnauthorizedLockRevert() public {
        vm.prank(intruder);
        vm.expectRevert(EscrowSwap.NotBuyer.selector);
        escrowSwap.lockFunds(escrowId, address(token), amount, encryptedKeyHash);
    }

    function testRevealKey() public {
        vm.prank(buyer);
        escrowSwap.lockFunds(escrowId, address(token), amount, encryptedKeyHash);

        vm.startPrank(seller);
        vm.expectEmit(true, false, false, false);
        emit KeyRevealed(escrowId);

        escrowSwap.revealKey(escrowId, secretKey);
        vm.stopPrank();

        EscrowSwap.EscrowAgreement memory agreement = escrowSwap.getAgreement(escrowId);
        assertEq(agreement.revealedKeyHash, secretKey);
    }

    function testDoubleRevealRevert() public {
        vm.prank(buyer);
        escrowSwap.lockFunds(escrowId, address(token), amount, encryptedKeyHash);

        vm.startPrank(seller);
        escrowSwap.revealKey(escrowId, secretKey);

        vm.expectRevert(EscrowSwap.AlreadyRevealed.selector);
        escrowSwap.revealKey(escrowId, secretKey);
        vm.stopPrank();
    }

    function testSuccessfulSettlement() public {
        vm.prank(buyer);
        escrowSwap.lockFunds(escrowId, address(token), amount, encryptedKeyHash);

        vm.prank(seller);
        escrowSwap.revealKey(escrowId, secretKey);

        uint256 initialSellerBalance = token.balanceOf(seller);

        vm.expectEmit(true, false, false, false);
        emit EscrowSettled(escrowId);

        escrowSwap.settle(escrowId);

        assertEq(token.balanceOf(seller), initialSellerBalance + amount);
        assertTrue(escrowSwap.getAgreement(escrowId).settled);
        assertTrue(escrowFSM.getEscrow(escrowId).status == EscrowStateMachine.EscrowStatus.COMPLETED);
    }

    function testInvalidRevealRefund() public {
        vm.prank(buyer);
        escrowSwap.lockFunds(escrowId, address(token), amount, encryptedKeyHash);

        // Seller reveals WRONG key
        vm.prank(seller);
        escrowSwap.revealKey(escrowId, wrongKeyHash);

        // Settle should fail
        vm.expectRevert(EscrowSwap.KeyHashMismatch.selector);
        escrowSwap.settle(escrowId);

        uint256 initialBuyerBalance = token.balanceOf(buyer);

        // Refund succeeds
        vm.expectEmit(true, false, false, false);
        emit EscrowRefunded(escrowId);

        escrowSwap.refund(escrowId);

        assertEq(token.balanceOf(buyer), initialBuyerBalance + amount);
        assertTrue(escrowSwap.getAgreement(escrowId).settled);
        assertTrue(escrowFSM.getEscrow(escrowId).status == EscrowStateMachine.EscrowStatus.REFUNDED);
    }

    function testGetterValidation() public {
        bytes32 dummyId = keccak256("dummy");
        EscrowSwap.EscrowAgreement memory agreement = escrowSwap.getAgreement(dummyId);
        assertFalse(agreement.exists);
        assertEq(agreement.amount, 0);
    }
}
