// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/access/NebulaAccessControl.sol";
import "../../src/governance/ParameterRegistry.sol";

contract ParameterRegistryTest is Test {
    NebulaAccessControl accessControl;
    ParameterRegistry registry;

    address admin = address(0x1);
    address nonAdmin = address(0x99);

    uint256 initMinimumStake = 1000 * 10 ** 18;
    uint256 initMarketplaceFeeBps = 250; // 2.5%
    uint256 initDisputeBond = 500 * 10 ** 18;
    uint64 initDisputeWindow = 7 days;
    uint64 initStakeLockPeriod = 14 days;
    bytes32 initProtocolVersion = keccak256("v1.0.0");

    event MinimumStakeUpdated(uint256 value);
    event MarketplaceFeeUpdated(uint256 value);
    event DisputeBondUpdated(uint256 value);
    event DisputeWindowUpdated(uint64 value);
    event StakeLockPeriodUpdated(uint64 value);
    event ProtocolVersionUpdated(bytes32 version);

    function setUp() public {
        vm.prank(admin);
        accessControl = new NebulaAccessControl(admin);

        registry = new ParameterRegistry(
            address(accessControl),
            initMinimumStake,
            initMarketplaceFeeBps,
            initDisputeBond,
            initDisputeWindow,
            initStakeLockPeriod,
            initProtocolVersion
        );
    }

    function testConstructorInitialization() public {
        ParameterRegistry.ProtocolParameters memory params = registry.getParameters();
        assertEq(params.minimumStake, initMinimumStake);
        assertEq(params.marketplaceFeeBps, initMarketplaceFeeBps);
        assertEq(params.disputeBond, initDisputeBond);
        assertEq(params.disputeWindow, initDisputeWindow);
        assertEq(params.stakeLockPeriod, initStakeLockPeriod);
        assertEq(params.protocolVersion, initProtocolVersion);
    }

    function testUpdateMinimumStake() public {
        uint256 newStake = 2000 * 10 ** 18;

        vm.startPrank(admin);
        vm.expectEmit(false, false, false, true);
        emit MinimumStakeUpdated(newStake);

        registry.setMinimumStake(newStake);
        vm.stopPrank();

        assertEq(registry.getParameters().minimumStake, newStake);
    }

    function testUpdateMarketplaceFee() public {
        uint256 newFee = 500; // 5%

        vm.startPrank(admin);
        vm.expectEmit(false, false, false, true);
        emit MarketplaceFeeUpdated(newFee);

        registry.setMarketplaceFee(newFee);
        vm.stopPrank();

        assertEq(registry.getParameters().marketplaceFeeBps, newFee);
    }

    function testUpdateDisputeBond() public {
        uint256 newBond = 1000 * 10 ** 18;

        vm.startPrank(admin);
        vm.expectEmit(false, false, false, true);
        emit DisputeBondUpdated(newBond);

        registry.setDisputeBond(newBond);
        vm.stopPrank();

        assertEq(registry.getParameters().disputeBond, newBond);
    }

    function testUpdateDisputeWindow() public {
        uint64 newWindow = 3 days;

        vm.startPrank(admin);
        vm.expectEmit(false, false, false, true);
        emit DisputeWindowUpdated(newWindow);

        registry.setDisputeWindow(newWindow);
        vm.stopPrank();

        assertEq(registry.getParameters().disputeWindow, newWindow);
    }

    function testUpdateStakeLockPeriod() public {
        uint64 newPeriod = 30 days;

        vm.startPrank(admin);
        vm.expectEmit(false, false, false, true);
        emit StakeLockPeriodUpdated(newPeriod);

        registry.setStakeLockPeriod(newPeriod);
        vm.stopPrank();

        assertEq(registry.getParameters().stakeLockPeriod, newPeriod);
    }

    function testUpdateProtocolVersion() public {
        bytes32 newVersion = keccak256("v2.0.0");

        vm.startPrank(admin);
        vm.expectEmit(false, false, false, true);
        emit ProtocolVersionUpdated(newVersion);

        registry.setProtocolVersion(newVersion);
        vm.stopPrank();

        assertEq(registry.getParameters().protocolVersion, newVersion);
    }

    function testUnauthorizedUpdateReverts() public {
        vm.startPrank(nonAdmin);

        vm.expectRevert(ParameterRegistry.NotAdmin.selector);
        registry.setMinimumStake(2000);

        vm.expectRevert(ParameterRegistry.NotAdmin.selector);
        registry.setMarketplaceFee(500);

        vm.expectRevert(ParameterRegistry.NotAdmin.selector);
        registry.setDisputeBond(1000);

        vm.expectRevert(ParameterRegistry.NotAdmin.selector);
        registry.setDisputeWindow(3 days);

        vm.expectRevert(ParameterRegistry.NotAdmin.selector);
        registry.setStakeLockPeriod(30 days);

        vm.expectRevert(ParameterRegistry.NotAdmin.selector);
        registry.setProtocolVersion(bytes32(0));

        vm.stopPrank();
    }

    function testInvalidValueReverts() public {
        vm.startPrank(admin);

        vm.expectRevert(ParameterRegistry.InvalidMinimumStake.selector);
        registry.setMinimumStake(0);

        vm.expectRevert(ParameterRegistry.InvalidMarketplaceFee.selector);
        registry.setMarketplaceFee(10001);

        vm.expectRevert(ParameterRegistry.InvalidDisputeBond.selector);
        registry.setDisputeBond(0);

        vm.expectRevert(ParameterRegistry.InvalidDisputeWindow.selector);
        registry.setDisputeWindow(0);

        vm.expectRevert(ParameterRegistry.InvalidStakeLockPeriod.selector);
        registry.setStakeLockPeriod(0);

        vm.expectRevert(ParameterRegistry.ZeroProtocolVersion.selector);
        registry.setProtocolVersion(bytes32(0));

        vm.stopPrank();
    }

    function testGetterValidation() public {
        ParameterRegistry.ProtocolParameters memory params = registry.getParameters();
        assertTrue(params.minimumStake > 0);
        assertTrue(params.marketplaceFeeBps <= 10000);
    }
}
