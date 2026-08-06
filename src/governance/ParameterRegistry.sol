// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NebulaAccessControl} from "../access/NebulaAccessControl.sol";

contract ParameterRegistry {
    struct ProtocolParameters {
        uint256 minimumStake;
        uint256 marketplaceFeeBps;
        uint256 disputeBond;
        uint64 disputeWindow;
        uint64 stakeLockPeriod;
        bytes32 protocolVersion;
    }

    NebulaAccessControl public immutable accessControl;
    ProtocolParameters private parameters;

    event MinimumStakeUpdated(uint256 value);
    event MarketplaceFeeUpdated(uint256 value);
    event DisputeBondUpdated(uint256 value);
    event DisputeWindowUpdated(uint64 value);
    event StakeLockPeriodUpdated(uint64 value);
    event ProtocolVersionUpdated(bytes32 version);

    error ZeroAddress();
    error InvalidMinimumStake();
    error InvalidMarketplaceFee();
    error InvalidDisputeBond();
    error InvalidDisputeWindow();
    error InvalidStakeLockPeriod();
    error ZeroProtocolVersion();
    error NotAdmin();

    constructor(
        address _accessControl,
        uint256 _minimumStake,
        uint256 _marketplaceFeeBps,
        uint256 _disputeBond,
        uint64 _disputeWindow,
        uint64 _stakeLockPeriod,
        bytes32 _protocolVersion
    ) {
        if (_accessControl == address(0)) {
            revert ZeroAddress();
        }
        if (_minimumStake == 0) {
            revert InvalidMinimumStake();
        }
        if (_marketplaceFeeBps > 10000) {
            revert InvalidMarketplaceFee();
        }
        if (_disputeBond == 0) {
            revert InvalidDisputeBond();
        }
        if (_disputeWindow == 0) {
            revert InvalidDisputeWindow();
        }
        if (_stakeLockPeriod == 0) {
            revert InvalidStakeLockPeriod();
        }
        if (_protocolVersion == bytes32(0)) {
            revert ZeroProtocolVersion();
        }

        accessControl = NebulaAccessControl(_accessControl);

        parameters = ProtocolParameters({
            minimumStake: _minimumStake,
            marketplaceFeeBps: _marketplaceFeeBps,
            disputeBond: _disputeBond,
            disputeWindow: _disputeWindow,
            stakeLockPeriod: _stakeLockPeriod,
            protocolVersion: _protocolVersion
        });
    }

    function setMinimumStake(uint256 value) external {
        _checkAdmin();
        if (value == 0) {
            revert InvalidMinimumStake();
        }
        parameters.minimumStake = value;
        emit MinimumStakeUpdated(value);
    }

    function setMarketplaceFee(uint256 value) external {
        _checkAdmin();
        if (value > 10000) {
            revert InvalidMarketplaceFee();
        }
        parameters.marketplaceFeeBps = value;
        emit MarketplaceFeeUpdated(value);
    }

    function setDisputeBond(uint256 value) external {
        _checkAdmin();
        if (value == 0) {
            revert InvalidDisputeBond();
        }
        parameters.disputeBond = value;
        emit DisputeBondUpdated(value);
    }

    function setDisputeWindow(uint64 value) external {
        _checkAdmin();
        if (value == 0) {
            revert InvalidDisputeWindow();
        }
        parameters.disputeWindow = value;
        emit DisputeWindowUpdated(value);
    }

    function setStakeLockPeriod(uint64 value) external {
        _checkAdmin();
        if (value == 0) {
            revert InvalidStakeLockPeriod();
        }
        parameters.stakeLockPeriod = value;
        emit StakeLockPeriodUpdated(value);
    }

    function setProtocolVersion(bytes32 version) external {
        _checkAdmin();
        if (version == bytes32(0)) {
            revert ZeroProtocolVersion();
        }
        parameters.protocolVersion = version;
        emit ProtocolVersionUpdated(version);
    }

    function getParameters() external view returns (ProtocolParameters memory) {
        return parameters;
    }

    function _checkAdmin() private view {
        if (!accessControl.hasRole(accessControl.DEFAULT_ADMIN_ROLE(), msg.sender)) {
            revert NotAdmin();
        }
    }
}
