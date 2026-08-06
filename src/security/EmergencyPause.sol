// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EmergencyPause is Pausable, Ownable {
    event EmergencyPaused(address indexed admin);
    event EmergencyResumed(address indexed admin);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function pause() external onlyOwner {
        _pause();
        emit EmergencyPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit EmergencyResumed(msg.sender);
    }
}
