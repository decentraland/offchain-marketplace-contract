// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CommonTypesHashing} from "src/common/CommonTypesHashing.sol";
import {MarketplaceTypes} from "src/marketplace/MarketplaceTypes.sol";

/// @notice Hashing functions for the Marketplace types. Used for EIP712 signatures.
abstract contract MarketplaceTypesHashing is MarketplaceTypes, CommonTypesHashing {
    // keccak256("AssetWithoutBeneficiary(uint256 assetType,address contractAddress,uint256 value,bytes extra)")
    bytes32 private constant ASSET_WO_BENEFICIARY_TYPE_HASH = 0x7be57332caf51c5f0f0fa0e7c362534d22d81c0bee1ffac9b573acd336e032bd;

    // keccak256("Asset(uint256 assetType,address contractAddress,uint256 value,bytes extra,address beneficiary)")
    bytes32 private constant ASSET_TYPE_HASH = 0xe5f9e1ebc316d1bde562c77f47da7dc2cccb903eb04f9b82e29212b96f9e57e1;

    // keccak256("Trade(Checks checks,AssetWithoutBeneficiary[] sent,Asset[] received)Asset(uint256 assetType,address contractAddress,uint256 value,bytes extra,address beneficiary)AssetWithoutBeneficiary(uint256 assetType,address contractAddress,uint256 value,bytes extra)Checks(uint256 uses,uint256 expiration,uint256 effective,bytes32 salt,uint256 contractSignatureIndex,uint256 signerSignatureIndex,bytes32 allowedRoot,ExternalCheck[] externalChecks)ExternalCheck(address contractAddress,bytes4 selector,bytes value,bool required)")
    bytes32 private constant TRADE_TYPE_HASH = 0x1bb41340c6ec0467bb14b59212e1189437e71660f2ef919bda2be2f2065dfe6c;

    function _hashAssetsWithoutBeneficiary(Asset[] calldata _assets) private pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](_assets.length);

        for (uint256 i = 0; i < hashes.length; i++) {
            Asset calldata asset = _assets[i];

            hashes[i] = keccak256(
                abi.encode(
                    ASSET_WO_BENEFICIARY_TYPE_HASH,
                    asset.assetType,
                    asset.contractAddress,
                    asset.value,
                    keccak256(asset.extra)
                )
            );
        }

        return keccak256(abi.encodePacked(hashes));
    }

    function _hashAssets(Asset[] calldata _assets) private pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](_assets.length);

        for (uint256 i = 0; i < hashes.length; i++) {
            Asset calldata asset = _assets[i];

            hashes[i] = keccak256(
                abi.encode(
                    ASSET_TYPE_HASH,
                    asset.assetType,
                    asset.contractAddress,
                    asset.value,
                    keccak256(asset.extra),
                    asset.beneficiary
                )
            );
        }

        return keccak256(abi.encodePacked(hashes));
    }

    function _hashTrade(Trade calldata _trade) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                TRADE_TYPE_HASH,
                _hashChecks(_trade.checks),
                _hashAssetsWithoutBeneficiary(_trade.sent),
                _hashAssets(_trade.received)
            )
        );
    }
}
