// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IAggregator} from "src/marketplace/interfaces/IAggregator.sol";
import {MarketplaceTypes} from "src/marketplace/MarketplaceTypes.sol";

/// @notice Contract that provides helper functions to handle Chainlink Aggregator results and related operations.
contract AggregatorHelper {
    error AggregatorAnswerIsNegative();
    error AggregatorAnswerIsStale();

    /// @dev Used to obtain the rate from an aggregator.
    /// @param _aggregator The aggregator used to obtain the rate.
    /// @param _staleTolerance The tolerated amount of seconds since the last update of the rate.
    /// @return The rate obtained from the aggregator, normalized to 18 decimals.
    function _getRateFromAggregator(IAggregator _aggregator, uint256 _staleTolerance) internal view returns (int256) {
        // Obtains rate values from the aggregator.
        (, int256 rate,, uint256 updatedAt,) = _aggregator.latestRoundData();

        // If the rate is negative, reverts.
        // This should not happen with currency aggregators but it's a good practice to check.
        if (rate < 0) {
            revert AggregatorAnswerIsNegative();
        }

        // If the result provided by the aggregator is too old, reverts.
        if (updatedAt < (block.timestamp - _staleTolerance)) {
            revert AggregatorAnswerIsStale();
        }

        // Obtains the number of decimals the rate has been returned as from the aggregator.
        uint8 decimals = _aggregator.decimals();

        // Normalizes the rate to 18 decimals.
        rate = rate * int256(10 ** (18 - decimals));

        return rate;
    }

    /// @dev Uses the original value in USD of the asset and updates it to MANA using the provided rate.
    /// Also updates the contract address to the MANA address given that it is the asset that will be transferred.
    function _updateAssetWithConvertedMANAPrice(MarketplaceTypes.Asset memory _asset, address _manaAddress, int256 _manaUsdRate)
        internal
        pure
        returns (MarketplaceTypes.Asset memory)
    {
        // Update the asset contract address to be MANA.
        _asset.contractAddress = _manaAddress;
        // Update the asset value to be the amount of MANA to be transferred.
        _asset.value = (_asset.value * uint256(_manaUsdRate)) / 1e18;

        return _asset;
    }
}
