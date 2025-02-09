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
        CollectionStoreInit memory _collectionStoreInit,
        MarketplaceStrategyInit memory _marketplaceInit,
        OffchainMarketplaceStrategyInit memory _offchainMarketplaceInit,
        ArbitraryCallInit memory _arbitraryCallInit,
        CreditManagerBaseInit memory _baseConstructorParams
    )
        CollectionStoreStrategy(_collectionStoreInit)
        MarketplaceStrategy(_marketplaceInit)
        OffchainMarketplaceStrategy(_offchainMarketplaceInit)
        ArbitraryCallStrategy(_arbitraryCallInit)
        CreditManagerBase(_baseConstructorParams)
    {}
}
