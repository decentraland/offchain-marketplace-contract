// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CreditManagerBase} from "src/credits/CreditManagerBase.sol";
import {CollectionStoreStrategy} from "src/credits/strategies/CollectionStoreStrategy.sol";
import {MarketplaceStrategy} from "src/credits/strategies/MarketplaceStrategy.sol";
import {OffchainMarketplaceStrategy} from "src/credits/strategies/OffchainMarketplaceStrategy.sol";
import {ArbitraryCallStrategy} from "src/credits/strategies/ArbitraryCallStrategy.sol";
import {ICollectionStore} from "src/credits/interfaces/ICollectionStore.sol";
import {IMarketplace} from "src/credits/interfaces/IMarketplace.sol";
import {MarketplaceWithCouponManager} from "src/marketplace/MarketplaceWithCouponManager.sol";
import {IManaUsdRateProvider} from "src/credits/rates/interfaces/IManaUsdRateProvider.sol";

contract CreditManager is CollectionStoreStrategy, MarketplaceStrategy, OffchainMarketplaceStrategy, ArbitraryCallStrategy {
    constructor(
        CollectionStoreStrategyInit memory _collectionStoreStrategyInit,
        MarketplaceStrategyInit memory _marketplaceStrategyInit,
        OffchainMarketplaceStrategyInit memory _offchainMarketplaceStrategyInit,
        ArbitraryCallStrategyInit memory _arbitraryCallStrategyInit,
        CreditManagerBaseInit memory _creditManagerBaseInit
    )
        CollectionStoreStrategy(_collectionStoreStrategyInit)
        MarketplaceStrategy(_marketplaceStrategyInit)
        OffchainMarketplaceStrategy(_offchainMarketplaceStrategyInit)
        ArbitraryCallStrategy(_arbitraryCallStrategyInit)
        CreditManagerBase(_creditManagerBaseInit)
    {}
}
