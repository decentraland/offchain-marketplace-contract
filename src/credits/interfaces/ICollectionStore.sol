// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ICollection} from "src/marketplace/interfaces/ICollection.sol";

interface ICollectionStore {
    struct ItemToBuy {
        ICollection collection;
        uint256[] ids;
        uint256[] prices;
        address[] beneficiaries;
    }

    function buy(ItemToBuy[] calldata _itemsToBuy) external;
}
