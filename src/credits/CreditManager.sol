// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CreditManagerBase} from "src/credits/CreditManagerBase.sol";
import {CollectionStoreStrategy} from "src/credits/strategies/CollectionStoreStrategy.sol";
import {ICollectionStore} from "src/credits/interfaces/ICollectionStore.sol";

contract CreditManager is CollectionStoreStrategy {
    constructor(ICollectionStore _collectionStore, BaseConstructorParams memory _baseConstructorParams)
        CollectionStoreStrategy(ICollectionStore(_collectionStore))
        CreditManagerBase(_baseConstructorParams)
    {}
}
