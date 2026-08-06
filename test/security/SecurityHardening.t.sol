// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/access/NebulaAccessControl.sol";
import "../../src/registry/AssetRegistry.sol";
import "../../src/marketplace/EscrowStateMachine.sol";
import "../../src/marketplace/EscrowSwap.sol";
import "../../src/staking/StakeVault.sol";
import "../../src/security/EmergencyPause.sol";

contract ReentrantToken is ERC20 {
    address public targetSwap;
    bytes32 public escrowId;
    bool public attackOnTransfer;

    constructor() ERC20("Reentrant Token", "RNT") {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function setAttackConfig(address _targetSwap, bytes32 _escrowId) external {
        targetSwap = _targetSwap;
        escrowId = _escrowId;
        attackOnTransfer = true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (attackOnTransfer) {
            attackOnTransfer = false; // Prevent infinite recursion in test environment
            // Attempt reentrant call into lockFunds
            EscrowSwap(targetSwap).lockFunds(escrowId, address(this), amount, keccak256("attack"));
        }
        return super.transferFrom(from, to, amount);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SecurityHardeningTest is Test {
    NebulaAccessControl accessControl;
    AssetRegistry assetRegistry;
    EscrowStateMachine escrowFSM;
    EmergencyPause emergencyPause;
    EscrowSwap escrowSwap;
    StakeVault stakeVault;
    ReentrantToken token;

    address admin = address(0x1);
    address seller = address(0x100);
    address buyer = address(0x200);
    address validator = address(0x300);
    address intruder = address(0x999);

    bytes32 assetHash = keccak256("sec_asset");
    bytes32 secretKey = keccak256("sec_secret");
    bytes32 encryptedKeyHash = keccak256(abi.encodePacked(secretKey));
    bytes32 assetId;
    bytes32 escrowId;
    uint256 amount = 1000 * 10 ** 18;

    event EmergencyPaused(address indexed admin);
    event EmergencyResumed(address indexed admin);

    function setUp() public {
        vm.startPrank(admin);
        accessControl = new NebulaAccessControl(admin);
        accessControl.grantValidator(validator);
        emergencyPause = new EmergencyPause(admin);
        vm.stopPrank();

        assetRegistry = new AssetRegistry();
        escrowFSM = new EscrowStateMachine(address(assetRegistry));
        escrowSwap = new EscrowSwap(address(escrowFSM), address(emergencyPause));
        stakeVault = new StakeVault(address(accessControl), address(emergencyPause));
        token = new ReentrantToken();

        token.mint(buyer, amount * 10);
        token.mint(validator, amount * 10);

        vm.prank(seller);
        assetId = assetRegistry.registerAsset(assetHash);

        vm.prank(seller);
        escrowId = escrowFSM.createEscrow(assetId, buyer);

        vm.prank(buyer);
        token.approve(address(escrowSwap), amount * 10);

        vm.prank(validator);
        token.approve(address(stakeVault), amount * 10);
    }

    function testReentrancyAttackFails() public {
        token.setAttackConfig(address(escrowSwap), escrowId);

        vm.prank(buyer);
        // Expect reentrancy guard revert
        vm.expectRevert();
        escrowSwap.lockFunds(escrowId, address(token), amount, encryptedKeyHash);
    }

    function testPauseBlocksDeposits() public {
        vm.prank(admin);
        emergencyPause.pause();

        vm.prank(validator);
        vm.expectRevert(StakeVault.ProtocolPaused.selector);
        stakeVault.depositStake(address(token), amount);
    }

    function testPauseBlocksSettlement() public {
        vm.prank(buyer);
        escrowSwap.lockFunds(escrowId, address(token), amount, encryptedKeyHash);

        vm.prank(seller);
        escrowSwap.revealKey(escrowId, secretKey);

        vm.prank(admin);
        emergencyPause.pause();

        vm.prank(seller);
        vm.expectRevert(EscrowSwap.ProtocolPaused.selector);
        escrowSwap.settle(escrowId);
    }

    function testPauseBlocksWithdrawals() public {
        vm.prank(validator);
        stakeVault.depositStake(address(token), amount);

        vm.prank(admin);
        emergencyPause.pause();

        vm.prank(validator);
        vm.expectRevert(StakeVault.ProtocolPaused.selector);
        stakeVault.releaseStake();
    }

    function testUnpauseRestoresOperation() public {
        vm.prank(admin);
        emergencyPause.pause();

        vm.prank(admin);
        emergencyPause.unpause();

        vm.prank(validator);
        stakeVault.depositStake(address(token), amount);

        StakeVault.Stake memory stake = stakeVault.getStake(validator);
        assertTrue(stake.exists);
        assertEq(stake.amount, amount);
    }

    function testUnauthorizedPauseReverts() public {
        vm.prank(intruder);
        vm.expectRevert();
        emergencyPause.pause();

        vm.prank(intruder);
        vm.expectRevert();
        emergencyPause.unpause();
    }
}
