// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NebulaAccessControl} from "../access/NebulaAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakeVault {
    using SafeERC20 for IERC20;

    enum StakeStatus {
        UNSTAKED,
        STAKED,
        LOCKED,
        SLASHED
    }

    struct Stake {
        bool exists;
        address validator;
        address token;
        uint256 amount;
        StakeStatus status;
        uint64 stakedAt;
        uint64 lockedUntil;
    }

    NebulaAccessControl public immutable accessControl;

    mapping(address => Stake) private stakes;

    event StakeDeposited(address indexed validator, uint256 amount);
    event StakeLocked(address indexed validator, uint64 until);
    event StakeReleased(address indexed validator);
    event StakeSlashed(address indexed validator, uint256 amount);

    error ZeroAddress();
    error ZeroTokenAddress();
    error ZeroAmount();
    error NotValidator();
    error NotDisputeRole();
    error StakeAlreadyExists();
    error StakeDoesNotExist();
    error StakeNotActive();
    error StakeStillLocked();
    error SlashAmountExceedsStake();
    error InvalidLockPeriod();

    constructor(address _accessControl) {
        if (_accessControl == address(0)) {
            revert ZeroAddress();
        }
        accessControl = NebulaAccessControl(_accessControl);
    }

    function depositStake(address token, uint256 amount) external {
        if (!accessControl.hasRole(accessControl.VALIDATOR_ROLE(), msg.sender)) {
            revert NotValidator();
        }
        if (token == address(0)) {
            revert ZeroTokenAddress();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        Stake storage stake = stakes[msg.sender];
        if (stake.status == StakeStatus.STAKED || stake.status == StakeStatus.LOCKED) {
            revert StakeAlreadyExists();
        }

        stakes[msg.sender] = Stake({
            exists: true,
            validator: msg.sender,
            token: token,
            amount: amount,
            status: StakeStatus.STAKED,
            stakedAt: uint64(block.timestamp),
            lockedUntil: 0
        });

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit StakeDeposited(msg.sender, amount);
    }

    function lockStake(address validator, uint64 until) external {
        if (!accessControl.hasRole(accessControl.DISPUTE_ROLE(), msg.sender)) {
            revert NotDisputeRole();
        }
        if (until <= block.timestamp) {
            revert InvalidLockPeriod();
        }

        Stake storage stake = stakes[validator];
        if (!stake.exists) {
            revert StakeDoesNotExist();
        }
        if (stake.status != StakeStatus.STAKED && stake.status != StakeStatus.LOCKED) {
            revert StakeNotActive();
        }

        stake.status = StakeStatus.LOCKED;
        stake.lockedUntil = until;

        emit StakeLocked(validator, until);
    }

    function releaseStake() external {
        Stake storage stake = stakes[msg.sender];
        if (!stake.exists) {
            revert StakeDoesNotExist();
        }
        if (stake.status != StakeStatus.STAKED && stake.status != StakeStatus.LOCKED) {
            revert StakeNotActive();
        }
        if (stake.status == StakeStatus.LOCKED && block.timestamp < stake.lockedUntil) {
            revert StakeStillLocked();
        }

        uint256 amountToRelease = stake.amount;
        address token = stake.token;

        stake.status = StakeStatus.UNSTAKED;
        stake.amount = 0;

        IERC20(token).safeTransfer(msg.sender, amountToRelease);

        emit StakeReleased(msg.sender);
    }

    function slashStake(address validator, uint256 amount) external {
        if (!accessControl.hasRole(accessControl.DISPUTE_ROLE(), msg.sender)) {
            revert NotDisputeRole();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        Stake storage stake = stakes[validator];
        if (!stake.exists) {
            revert StakeDoesNotExist();
        }
        if (stake.status != StakeStatus.STAKED && stake.status != StakeStatus.LOCKED) {
            revert StakeNotActive();
        }
        if (amount > stake.amount) {
            revert SlashAmountExceedsStake();
        }

        stake.amount -= amount;
        if (stake.amount == 0) {
            stake.status = StakeStatus.SLASHED;
        }

        emit StakeSlashed(validator, amount);
    }

    function getStake(address validator) external view returns (Stake memory) {
        return stakes[validator];
    }
}
