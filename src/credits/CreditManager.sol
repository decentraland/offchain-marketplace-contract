// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CreditManagerBase} from "src/credits/CreditManagerBase.sol";
import {CollectionStoreStrategy} from "src/credits/strategies/CollectionStoreStrategy.sol";
import {MarketplaceStrategy} from "src/credits/strategies/MarketplaceStrategy.sol";
import {OffchainMarketplaceStrategy} from "src/credits/strategies/OffchainMarketplaceStrategy.sol";
import {ICollectionStore} from "src/credits/interfaces/ICollectionStore.sol";
import {IMarketplace} from "src/credits/interfaces/IMarketplace.sol";
import {MarketplaceWithCouponManager} from "src/marketplace/MarketplaceWithCouponManager.sol";
import {IManaUsdRateProvider} from "src/credits/rates/interfaces/IManaUsdRateProvider.sol";

contract CreditManager is CollectionStoreStrategy, MarketplaceStrategy, OffchainMarketplaceStrategy {
    constructor(
        ICollectionStore _collectionStore,
        IMarketplace _marketplace,
        MarketplaceWithCouponManager _offchainMarketplace,
        IManaUsdRateProvider _manaUsdRateProvider,
        BaseConstructorParams memory _baseConstructorParams
    )
        CollectionStoreStrategy(ICollectionStore(_collectionStore))
        MarketplaceStrategy(_marketplace)
        OffchainMarketplaceStrategy(_offchainMarketplace, _manaUsdRateProvider)
        CreditManagerBase(_baseConstructorParams)
    {}
}
