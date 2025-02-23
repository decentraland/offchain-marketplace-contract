// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

struct ItemToBuy {
    address collection;
    uint256[] ids;
    uint256[] prices;
    address[] beneficiaries;
}

interface ICollectionStore {
    function buy(ItemToBuy[] memory _itemsToBuy) external;
}
