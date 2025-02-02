// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IMarketplace {
    function safeExecuteOrder(address _nftAddress, uint256 _assetId, uint256 _price, bytes calldata _fingerprint) external;
    function executeOrder(address _nftAddress, uint256 _assetId, uint256 _price) external;
}
