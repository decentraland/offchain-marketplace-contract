// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IAggregator} from "src/marketplace/interfaces/IAggregator.sol";

contract MockAggregator is IAggregator {
    address public owner;
    int256 public answer;
    uint256 public updatedAtOffset;
    uint8 public decimalsResult;

    constructor(address _owner, int256 _answer, uint256 _updatedAtOffset, uint8 _decimalsResult) {
        owner = _owner;
        answer = _answer;
        updatedAtOffset = _updatedAtOffset;
        decimalsResult = _decimalsResult;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only Owner");
        _;
    }

    function decimals() external view returns (uint8) {
        return decimalsResult;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, answer, 0, block.timestamp - updatedAtOffset, 0);
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    function setAnswer(int256 _answer) external onlyOwner {
        answer = _answer;
    }

    function setUpdatedAtOffset(uint256 _updatedAtOffset) external onlyOwner {
        updatedAtOffset = _updatedAtOffset;
    }

    function setDecimalsResult(uint8 _decimalsResult) external onlyOwner {
        decimalsResult = _decimalsResult;
    }
}
