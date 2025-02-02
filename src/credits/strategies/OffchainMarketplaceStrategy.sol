// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CreditManagerBase} from "src/credits/CreditManagerBase.sol";
import {MarketplaceWithCouponManager} from "src/marketplace/MarketplaceWithCouponManager.sol";
import {DecentralandMarketplacePolygonAssetTypes} from "src/marketplace/DecentralandMarketplacePolygonAssetTypes.sol";
import {IManaUsdRateProvider} from "src/credits/rates/interfaces/IManaUsdRateProvider.sol";

abstract contract OffchainMarketplaceStrategy is CreditManagerBase, DecentralandMarketplacePolygonAssetTypes {
    MarketplaceWithCouponManager public immutable offchainMarketplace;
    IManaUsdRateProvider public immutable manaUsdRateProvider;

    constructor(MarketplaceWithCouponManager _offchainMarketplace, IManaUsdRateProvider _manaUsdRateProvider) {
        offchainMarketplace = _offchainMarketplace;
        manaUsdRateProvider = _manaUsdRateProvider;
    }

    function executeOffchainMarketplaceAccept(MarketplaceWithCouponManager.Trade[] memory _trades, Credit[] calldata _credits) external {
        _validateTrades(_trades);
        
        uint256 totalManaToTransfer = _computeTotalManaToTransfer(_trades);

        _consumeCredits(_credits, totalManaToTransfer);

        mana.approve(address(offchainMarketplace), totalManaToTransfer);

        uint256 balanceBefore = mana.balanceOf(address(this));

        offchainMarketplace.accept(_trades);

        if (balanceBefore - mana.balanceOf(address(this)) != totalManaToTransfer) {
            revert("MANA transfer mismatch");
        }
    }

    function _validateTrades(MarketplaceWithCouponManager.Trade[] memory _trades) private view {
        if (_trades.length == 0) {
            revert("Invalid Trades Length");
        }

        for (uint256 i = 0; i < _trades.length; i++) {
            MarketplaceWithCouponManager.Asset[] memory received = _trades[i].received;

            if (received.length != 1) {
                revert("Invalid Received Length");
            }

            if (received[0].contractAddress != address(mana)) {
                revert("Invalid Contract Address");
            }

            if (received[0].assetType != ASSET_TYPE_ERC20 && received[0].assetType != ASSET_TYPE_USD_PEGGED_MANA) {
                revert("Invalid Asset Type");
            }

            MarketplaceWithCouponManager.Asset[] memory sent = _trades[i].sent;

            if (sent.length == 0) {
                revert("Invalid Sent Length");
            }

            for (uint256 j = 0; j < sent.length; j++) {
                _validateIsDecentralandItem(sent[j].contractAddress);

                if (sent[j].assetType == ASSET_TYPE_ERC721) {
                    _validateSecondarySalesAllowed();
                } else if (sent[j].assetType == ASSET_TYPE_COLLECTION_ITEM) {
                    _validatePrimarySalesAllowed();
                } else {
                    revert("Invalid Sent Asset Type");
                }

                if (sent[j].beneficiary == address(0)) {
                    sent[j].beneficiary = _msgSender();
                }
            }
        }
    }

    function _computeTotalManaToTransfer(MarketplaceWithCouponManager.Trade[] memory _trades) private view returns (uint256 totalManaToTransfer) {
        uint256 manaUsdRate = manaUsdRateProvider.getManaUsdRate();

        for (uint256 i = 0; i < _trades.length; i++) {
            MarketplaceWithCouponManager.Asset memory received = _trades[i].received[0];

            if (received.assetType == ASSET_TYPE_ERC20) {
                totalManaToTransfer += received.value;
            } else if (received.assetType == ASSET_TYPE_USD_PEGGED_MANA) {
                totalManaToTransfer += received.value * 1e18 / manaUsdRate;
            }
        }
    }
}
