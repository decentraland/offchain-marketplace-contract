// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {CreditManagerBase} from "src/credits/CreditManagerBase.sol";
import {ICollectionStore} from "src/credits/interfaces/ICollectionStore.sol";
import {ICollection} from "src/marketplace/interfaces/ICollection.sol";

abstract contract CollectionStoreStrategy is CreditManagerBase {
    ICollectionStore public immutable collectionStore;

    constructor(ICollectionStore _collectionStore) {
        collectionStore = _collectionStore;
    }

    function executeCollectionStoreBuy(ICollectionStore.ItemToBuy[] calldata _itemsToBuy, Credit[] calldata _credits) external nonReentrant {
        _validatePrimarySalesAllowed();

        if (_itemsToBuy.length == 0) {
            revert("Invalid input");
        }

        uint256 totalManaToTransfer;

        for (uint256 i = 0; i < _itemsToBuy.length; i++) {
            ICollectionStore.ItemToBuy calldata itemToBuy = _itemsToBuy[i];

            _validateIsDecentralandItem(address(itemToBuy.collection));

            for (uint256 j = 0; j < itemToBuy.prices.length; j++) {
                totalManaToTransfer += itemToBuy.prices[j];
            }
        }

        _consumeCredits(_credits, totalManaToTransfer);

        mana.approve(address(collectionStore), totalManaToTransfer);

        uint256 balanceBefore = mana.balanceOf(address(this));

        collectionStore.buy(_itemsToBuy);

        _validateResultingBalance(balanceBefore, totalManaToTransfer);
    }
}
