// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Interface for Chainlink Aggregator contracts containing the methods used by the Marketplace contracts to obtain a rate.
interface IAggregator {
    /// @notice Returns the number of decimals used by the Aggregator.
    /// For example, MANA / ETH returns 18 decimals while ETH / USD returns 8 decimals.
    /// Required to normalize the rate.
    function decimals() external view returns (uint8);

    /// @notice Function that returns the most recent rate.
    /// The value currently used are "answer", containing the rate, and the "updatedAt" timestamp used to know if the value is not too old.
    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
