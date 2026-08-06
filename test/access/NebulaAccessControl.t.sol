// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/access/NebulaAccessControl.sol";

contract NebulaAccessControlTest is Test {
    NebulaAccessControl accessControl;

    address admin = address(1);
    address validator = address(2);

    function setUp() public {
        vm.prank(admin);
        accessControl = new NebulaAccessControl(admin);
    }

    function testAdminRoleAssigned() public {
        assertTrue(accessControl.hasRole(accessControl.DEFAULT_ADMIN_ROLE(), admin));
    }

    function testGrantValidatorRole() public {
        vm.prank(admin);

        accessControl.grantValidator(validator);

        assertTrue(accessControl.hasRole(accessControl.VALIDATOR_ROLE(), validator));
    }

    function testRevokeValidatorRole() public {
        vm.startPrank(admin);

        accessControl.grantValidator(validator);
        accessControl.revokeValidator(validator);

        vm.stopPrank();

        assertFalse(accessControl.hasRole(accessControl.VALIDATOR_ROLE(), validator));
    }

    function testUnauthorizedGrantReverts() public {
        vm.expectRevert();

        accessControl.grantValidator(validator);
    }
}
