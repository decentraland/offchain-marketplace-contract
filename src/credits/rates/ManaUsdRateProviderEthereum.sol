// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IManaUsdRateProvider} from "src/credits/rates/interfaces/IManaUsdRateProvider.sol";
import {DecentralandMarketplaceEthereum} from "src/marketplace/DecentralandMarketplaceEthereum.sol";
import {AggregatorHelper} from "src/marketplace/AggregatorHelper.sol";

contract ManaUsdRateProviderEthereum is IManaUsdRateProvider, AggregatorHelper {
    DecentralandMarketplaceEthereum public immutable marketplace;

    constructor(DecentralandMarketplaceEthereum _marketplace) {
        marketplace = _marketplace;
    }

    function getManaUsdRate() external view returns (uint256) {
        // Obtains the price of MANA in ETH.
        int256 manaEthRate = _getRateFromAggregator(marketplace.manaEthAggregator(), marketplace.manaEthAggregatorTolerance());

        // Obtains the price of ETH in USD.
        int256 ethUsdRate = _getRateFromAggregator(marketplace.ethUsdAggregator(), marketplace.ethUsdAggregatorTolerance());

        // With the obtained rates, we can calculate the price of MANA in USD.
        int256 manaUsdRate = (manaEthRate * ethUsdRate) / 1e18;

        return uint256(manaUsdRate);
    }
}
