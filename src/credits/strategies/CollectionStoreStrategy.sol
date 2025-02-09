// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CreditManagerBase} from "src/credits/CreditManagerBase.sol";
import {ICollectionStore} from "src/credits/interfaces/ICollectionStore.sol";
import {ICollection} from "src/marketplace/interfaces/ICollection.sol";

abstract contract CollectionStoreStrategy is CreditManagerBase {
    ICollectionStore public immutable collectionStore;

    /// @param _collectionStore The collection store contract.
    struct CollectionStoreStrategyInit {
        ICollectionStore collectionStore;
    }

    /// @param _init The initialization parameters for the contract.
    constructor(CollectionStoreStrategyInit memory _init) {
        collectionStore = _init.collectionStore;
    }

    function executeCollectionStoreBuy(ICollectionStore.ItemToBuy[] calldata _itemsToBuy, Credit[] calldata _credits) external nonReentrant {
        _validatePrimarySalesAllowed();

        if (_itemsToBuy.length == 0) {
            revert("Invalid input");
        }

        uint256 totalManaToTransfer;

        for (uint256 i = 0; i < _itemsToBuy.length; i++) {
            ICollectionStore.ItemToBuy calldata itemToBuy = _itemsToBuy[i];

            _validateContractAddress(address(itemToBuy.collection));

            for (uint256 j = 0; j < itemToBuy.prices.length; j++) {
                totalManaToTransfer += itemToBuy.prices[j];
            }
        }

        uint256 manaToCredit = _computeTotalManaToCredit(_credits, totalManaToTransfer);

        mana.approve(address(collectionStore), totalManaToTransfer);

        uint256 balanceBefore = mana.balanceOf(address(this));

        collectionStore.buy(_itemsToBuy);

        _validateResultingBalance(balanceBefore, totalManaToTransfer);

        _executeManaTransfers(manaToCredit, totalManaToTransfer);
    }
}
