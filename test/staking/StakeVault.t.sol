// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/access/NebulaAccessControl.sol";
import "../../src/staking/StakeVault.sol";
import "../../src/security/EmergencyPause.sol";

contract MockStakeToken is ERC20 {
    constructor() ERC20("Stake Token", "STK") {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract StakeVaultTest is Test {
    NebulaAccessControl accessControl;
    StakeVault stakeVault;
    EmergencyPause emergencyPause;
    MockStakeToken token;

    address admin = address(0x1);
    address validator1 = address(0x10);
    address validator2 = address(0x20);
    address disputeAdmin = address(0x30);
    address nonValidator = address(0x99);

    uint256 stakeAmount = 5000 * 10 ** 18;

    event StakeDeposited(address indexed validator, uint256 amount);
    event StakeLocked(address indexed validator, uint64 until);
    event StakeReleased(address indexed validator);
    event StakeSlashed(address indexed validator, uint256 amount);

    function setUp() public {
        vm.startPrank(admin);
        accessControl = new NebulaAccessControl(admin);

        accessControl.grantValidator(validator1);
        accessControl.grantValidator(validator2);
        accessControl.grantDispute(disputeAdmin);

        emergencyPause = new EmergencyPause(admin);
        stakeVault = new StakeVault(address(accessControl), address(emergencyPause));
        vm.stopPrank();

        token = new MockStakeToken();

        token.mint(validator1, stakeAmount * 10);
        token.mint(validator2, stakeAmount * 10);

        vm.prank(validator1);
        token.approve(address(stakeVault), stakeAmount * 10);

        vm.prank(validator2);
        token.approve(address(stakeVault), stakeAmount * 10);
    }

    function testStakeDeposit() public {
        vm.startPrank(validator1);

        vm.expectEmit(true, false, false, true);
        emit StakeDeposited(validator1, stakeAmount);

        stakeVault.depositStake(address(token), stakeAmount);
        vm.stopPrank();

        StakeVault.Stake memory stake = stakeVault.getStake(validator1);
        assertTrue(stake.exists);
        assertEq(stake.validator, validator1);
        assertEq(stake.token, address(token));
        assertEq(stake.amount, stakeAmount);
        assertTrue(stake.status == StakeVault.StakeStatus.STAKED);
        assertEq(token.balanceOf(address(stakeVault)), stakeAmount);
    }

    function testZeroAmountRejection() public {
        vm.prank(validator1);
        vm.expectRevert(StakeVault.ZeroAmount.selector);
        stakeVault.depositStake(address(token), 0);
    }

    function testZeroTokenRejection() public {
        vm.prank(validator1);
        vm.expectRevert(StakeVault.ZeroTokenAddress.selector);
        stakeVault.depositStake(address(0), stakeAmount);
    }

    function testNonValidatorRevert() public {
        vm.prank(nonValidator);
        vm.expectRevert(StakeVault.NotValidator.selector);
        stakeVault.depositStake(address(token), stakeAmount);
    }

    function testDuplicateStakeRevert() public {
        vm.startPrank(validator1);
        stakeVault.depositStake(address(token), stakeAmount);

        vm.expectRevert(StakeVault.StakeAlreadyExists.selector);
        stakeVault.depositStake(address(token), stakeAmount);
        vm.stopPrank();
    }

    function testLockStake() public {
        vm.prank(validator1);
        stakeVault.depositStake(address(token), stakeAmount);

        uint64 lockUntil = uint64(block.timestamp + 1 days);

        vm.startPrank(disputeAdmin);
        vm.expectEmit(true, false, false, true);
        emit StakeLocked(validator1, lockUntil);

        stakeVault.lockStake(validator1, lockUntil);
        vm.stopPrank();

        StakeVault.Stake memory stake = stakeVault.getStake(validator1);
        assertTrue(stake.status == StakeVault.StakeStatus.LOCKED);
        assertEq(stake.lockedUntil, lockUntil);
    }

    function testReleaseAfterLockExpires() public {
        vm.prank(validator1);
        stakeVault.depositStake(address(token), stakeAmount);

        uint64 lockUntil = uint64(block.timestamp + 1 days);
        vm.prank(disputeAdmin);
        stakeVault.lockStake(validator1, lockUntil);

        // Advance time past lock
        vm.warp(lockUntil + 1);

        uint256 initialBalance = token.balanceOf(validator1);

        vm.startPrank(validator1);
        vm.expectEmit(true, false, false, false);
        emit StakeReleased(validator1);

        stakeVault.releaseStake();
        vm.stopPrank();

        assertEq(token.balanceOf(validator1), initialBalance + stakeAmount);
        assertTrue(stakeVault.getStake(validator1).status == StakeVault.StakeStatus.UNSTAKED);
    }

    function testEarlyReleaseRevert() public {
        vm.prank(validator1);
        stakeVault.depositStake(address(token), stakeAmount);

        uint64 lockUntil = uint64(block.timestamp + 1 days);
        vm.prank(disputeAdmin);
        stakeVault.lockStake(validator1, lockUntil);

        vm.prank(validator1);
        vm.expectRevert(StakeVault.StakeStillLocked.selector);
        stakeVault.releaseStake();
    }

    function testSlashStake() public {
        vm.prank(validator1);
        stakeVault.depositStake(address(token), stakeAmount);

        uint256 slashAmount = 2000 * 10 ** 18;

        vm.startPrank(disputeAdmin);
        vm.expectEmit(true, false, false, true);
        emit StakeSlashed(validator1, slashAmount);

        stakeVault.slashStake(validator1, slashAmount);
        vm.stopPrank();

        StakeVault.Stake memory stake = stakeVault.getStake(validator1);
        assertEq(stake.amount, stakeAmount - slashAmount);

        // Full slash updates status to SLASHED
        vm.prank(disputeAdmin);
        stakeVault.slashStake(validator1, stakeAmount - slashAmount);
        assertTrue(stakeVault.getStake(validator1).status == StakeVault.StakeStatus.SLASHED);
    }

    function testOverSlashRevert() public {
        vm.prank(validator1);
        stakeVault.depositStake(address(token), stakeAmount);

        vm.prank(disputeAdmin);
        vm.expectRevert(StakeVault.SlashAmountExceedsStake.selector);
        stakeVault.slashStake(validator1, stakeAmount + 1);
    }

    function testGetterValidation() public {
        StakeVault.Stake memory stake = stakeVault.getStake(nonValidator);
        assertFalse(stake.exists);
        assertEq(stake.amount, 0);
    }
}
