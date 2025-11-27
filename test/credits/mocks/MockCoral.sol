// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Mock contract for Coral bridge's fundAndRunMulticall function
contract MockCoral {
    struct Call {
        uint8 callType;
        address target;
        uint256 value;
        bytes callData;
        bytes payload;
    }

    event FundAndRunMulticallCalled(address token, uint256 amount, Call[] calls);

    address public owner;
    bool public shouldRevert;
    uint256 public lastAmountReceived;
    address public lastTokenReceived;
    address public reentrancyCallback;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function fundAndRunMulticall(address token, uint256 amount, Call[] calldata calls) external payable {
        if (shouldRevert) {
            revert("Mock Coral: Forced revert");
        }

        lastTokenReceived = token;
        lastAmountReceived = amount;

        // Transfer tokens from sender to this contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // If reentrancy callback is set, call it to attempt reentrancy
        if (reentrancyCallback != address(0)) {
            // Call the callback - if it reverts (reentrancy detected), propagate the revert
            // Using assembly to properly propagate the revert data
            address callback = reentrancyCallback;
            assembly {
                let result := call(gas(), callback, 0, 0, 0, 0, 0)
                if iszero(result) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }

        emit FundAndRunMulticallCalled(token, amount, calls);
    }

    function setReentrancyCallback(address _callback) external onlyOwner {
        reentrancyCallback = _callback;
    }

    function setShouldRevert(bool _shouldRevert) external onlyOwner {
        shouldRevert = _shouldRevert;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }
}

