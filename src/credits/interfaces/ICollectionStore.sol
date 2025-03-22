// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ICollectionStore {
    struct ItemToBuy {
        address collection;
        uint256[] ids;
        uint256[] prices;
        address[] beneficiaries;
    }

    function buy(ItemToBuy[] memory _itemsToBuy) external;
}
