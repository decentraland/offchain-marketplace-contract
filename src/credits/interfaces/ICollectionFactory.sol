// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ICollectionFactory {
    function isCollectionFromFactory(address _collection) external view returns (bool);
}
