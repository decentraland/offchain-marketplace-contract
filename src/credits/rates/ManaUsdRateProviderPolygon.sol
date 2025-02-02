// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IManaUsdRateProvider} from "src/credits/rates/interfaces/IManaUsdRateProvider.sol";
import {AggregatorHelper} from "src/marketplace/AggregatorHelper.sol";
import {DecentralandMarketplacePolygon} from "src/marketplace/DecentralandMarketplacePolygon.sol";

contract ManaUsdRateProviderPolygon is IManaUsdRateProvider, AggregatorHelper {
    DecentralandMarketplacePolygon public immutable marketplace;

    constructor(DecentralandMarketplacePolygon _marketplace) {
        marketplace = _marketplace;
    }

    function getManaUsdRate() external view returns (uint256) {
        // Obtains the price of MANA in USD.
        int256 manaUsdRate = _getRateFromAggregator(marketplace.manaUsdAggregator(), marketplace.manaUsdAggregatorTolerance());

        return uint256(manaUsdRate);
    }
}
