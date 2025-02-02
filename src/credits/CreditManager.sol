// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CreditManagerBase} from "src/credits/CreditManagerBase.sol";
import {CollectionStoreStrategy} from "src/credits/strategies/CollectionStoreStrategy.sol";
import {MarketplaceStrategy} from "src/credits/strategies/MarketplaceStrategy.sol";
import {ICollectionStore} from "src/credits/interfaces/ICollectionStore.sol";
import {IMarketplace} from "src/credits/interfaces/IMarketplace.sol";

contract CreditManager is CollectionStoreStrategy, MarketplaceStrategy {
    constructor(ICollectionStore _collectionStore, IMarketplace _marketplace, BaseConstructorParams memory _baseConstructorParams)
        CollectionStoreStrategy(ICollectionStore(_collectionStore))
        MarketplaceStrategy(_marketplace)
        CreditManagerBase(_baseConstructorParams)
    {}
}
