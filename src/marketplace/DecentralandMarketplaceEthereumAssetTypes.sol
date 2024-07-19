// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

/// @notice Asset types for the Decentraland Marketplace on Ethereum.
abstract contract DecentralandMarketplaceEthereumAssetTypes {
    uint256 public constant ASSET_TYPE_ERC20 = 1;
    uint256 public constant ASSET_TYPE_USD_PEGGED_MANA = 2;
    uint256 public constant ASSET_TYPE_ERC721 = 3;

    error UnsupportedAssetType(uint256 _assetType);
}
