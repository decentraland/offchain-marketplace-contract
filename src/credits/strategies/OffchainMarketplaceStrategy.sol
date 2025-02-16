// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CreditManagerBase} from "src/credits/CreditManagerBase.sol";
import {MarketplaceWithCouponManager} from "src/marketplace/MarketplaceWithCouponManager.sol";
import {DecentralandMarketplacePolygonAssetTypes} from "src/marketplace/DecentralandMarketplacePolygonAssetTypes.sol";
import {IManaUsdRateProvider} from "src/credits/rates/interfaces/IManaUsdRateProvider.sol";
import {ICoupon} from "src/coupons/interfaces/ICoupon.sol";

abstract contract OffchainMarketplaceStrategy is CreditManagerBase, DecentralandMarketplacePolygonAssetTypes {
    using SafeERC20 for IERC20;

    MarketplaceWithCouponManager public immutable offchainMarketplace;
    IManaUsdRateProvider public immutable manaUsdRateProvider;

    bytes32 private externalCheckCreditsHash;

    /// @param _offchainMarketplace The offchain marketplace contract.
    /// @param _manaUsdRateProvider The MANA/USD rate provider contract.
    struct OffchainMarketplaceStrategyInit {
        MarketplaceWithCouponManager offchainMarketplace;
        IManaUsdRateProvider manaUsdRateProvider;
    }

    /// @param _init The initialization parameters for the contract.
    constructor(OffchainMarketplaceStrategyInit memory _init) {
        offchainMarketplace = _init.offchainMarketplace;
        manaUsdRateProvider = _init.manaUsdRateProvider;
    }

    function executeOffchainMarketplaceAccept(
        MarketplaceWithCouponManager.Trade[] calldata _trades,
        MarketplaceWithCouponManager.Coupon[] calldata _coupons,
        Credit[] calldata _credits,
        bool _isListing
    ) external nonReentrant {
        if (_isListing) {   
            _validateListingTrades(_trades);
        } else {
            _validateBidTrades(_trades);

            bytes[] memory creditSignatures = new bytes[](_credits.length);

            for (uint256 i = 0; i < _credits.length; i++) {
                creditSignatures[i] = _credits[i].signature;
            }

            externalCheckCreditsHash = keccak256(abi.encode(creditSignatures));
        }

        uint256 couponsLength = _coupons.length;
        uint256 tradesLength = _trades.length;
        uint256 totalManaToTransfer;

        if (couponsLength == 0) {
            totalManaToTransfer = _computeTotalManaToTransfer(_trades, _isListing);
        } else {
            MarketplaceWithCouponManager.Trade[] memory tradesWithAppliedCoupons = _trades;

            for (uint256 i = 0; i < tradesLength; i++) {
                address couponAddress = _coupons[i].couponAddress;
                ICoupon coupon = ICoupon(couponAddress);
                tradesWithAppliedCoupons[i] = coupon.applyCoupon(tradesWithAppliedCoupons[i], _coupons[i]);
            }

            totalManaToTransfer = _computeTotalManaToTransfer(tradesWithAppliedCoupons, _isListing);
        }

        uint256 manaToCredit = _computeTotalManaToCredit(_credits, totalManaToTransfer);

        mana.forceApprove(address(offchainMarketplace), totalManaToTransfer);

        uint256 balanceBefore = mana.balanceOf(address(this));
        MarketplaceWithCouponManager.Trade[] memory trades = _trades;

        if (_isListing) {
            for (uint256 i = 0; i < tradesLength; i++) {
                trades[i].received[0].beneficiary = _msgSender();
            }
        }

        if (couponsLength == 0) {
            offchainMarketplace.accept(trades);
        } else {
            offchainMarketplace.acceptWithCoupon(trades, _coupons);
        }

        if (!_isListing) {
            delete externalCheckCreditsHash;
        }

        _validateResultingBalance(balanceBefore, totalManaToTransfer);

        _transferDiffBackToContract(manaToCredit, totalManaToTransfer);
    }

    function bidsExternalCheck(address _marketplaceCaller, bytes calldata _data) external view returns (bool) {
        if (_marketplaceCaller != address(this)) {
            return false;
        }

        bytes32 creditsHash = abi.decode(_data, (bytes32));

        return externalCheckCreditsHash == creditsHash;
    }

    function _validateListingTrades(MarketplaceWithCouponManager.Trade[] calldata _trades) private view {
        uint256 tradesLength = _trades.length;

        if (tradesLength == 0) {
            revert("Invalid Trades Length");
        }

        for (uint256 i = 0; i < tradesLength; i++) {
            MarketplaceWithCouponManager.Trade calldata trade = _trades[i];

            _validateManaAssets(trade.received);

            _validateNonManaAssets(trade.sent);
        }
    }

    function _validateBidTrades(MarketplaceWithCouponManager.Trade[] calldata _trades) private view {
        uint256 tradesLength = _trades.length;

        if (tradesLength == 0) {
            revert("Invalid Trades Length");
        }

        for (uint256 i = 0; i < tradesLength; i++) {
            MarketplaceWithCouponManager.Trade calldata trade = _trades[i];

            _validateManaAssets(trade.sent);

            _validateNonManaAssets(trade.received);
        }
    }

    function _validateManaAssets(MarketplaceWithCouponManager.Asset[] calldata _assets) private view {
        if (_assets.length != 1) {
            revert("Invalid Assets Length");
        }

        MarketplaceWithCouponManager.Asset calldata asset = _assets[0];

        if (asset.contractAddress != address(mana)) {
            revert("Invalid Contract Address");
        }

        if (asset.assetType != ASSET_TYPE_ERC20 && asset.assetType != ASSET_TYPE_USD_PEGGED_MANA) {
            revert("Invalid Asset Type");
        }
    }

    function _validateNonManaAssets(MarketplaceWithCouponManager.Asset[] calldata _assets) private view {
        if (_assets.length == 0) {
            revert("Invalid Received Length");
        }

        for (uint256 j = 0; j < _assets.length; j++) {
            MarketplaceWithCouponManager.Asset calldata asset = _assets[j];

            _validateContractAddress(asset.contractAddress);

            if (asset.assetType == ASSET_TYPE_ERC721) {
                _validateSecondarySalesAllowed();
            } else if (asset.assetType == ASSET_TYPE_COLLECTION_ITEM) {
                _validatePrimarySalesAllowed();
            } else {
                revert("Invalid Received Asset Type");
            }
        }
    }

    function _computeTotalManaToTransfer(MarketplaceWithCouponManager.Trade[] memory _trades, bool _isListing)
        private
        view
        returns (uint256 totalManaToTransfer)
    {
        uint256 manaUsdRate = manaUsdRateProvider.getManaUsdRate();

        for (uint256 i = 0; i < _trades.length; i++) {
            MarketplaceWithCouponManager.Asset memory asset;

            if (_isListing) {
                asset = _trades[i].received[0];
            } else {
                asset = _trades[i].sent[0];
            }

            if (asset.assetType == ASSET_TYPE_ERC20) {
                totalManaToTransfer += asset.value;
            } else if (asset.assetType == ASSET_TYPE_USD_PEGGED_MANA) {
                totalManaToTransfer += asset.value * 1e18 / manaUsdRate;
            }
        }
    }
}
