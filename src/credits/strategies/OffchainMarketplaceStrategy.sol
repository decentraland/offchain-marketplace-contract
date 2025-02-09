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

    /// @dev _trades is defined in memory to allow _validateTrades to update the sent asset beneficiaries from address(0) to
    /// the caller and prevent this contract from receiving the assets.
    function executeOffchainMarketplaceAccept(MarketplaceWithCouponManager.Trade[] memory _trades, Credit[] calldata _credits)
        external
        nonReentrant
    {
        _validateTrades(_trades);

        // Calculates how much mana will be transferred after the trades are accepted.
        uint256 totalManaToTransfer = _computeTotalManaToTransfer(_trades);

        uint256 manaToCredit = _computeTotalManaToCredit(_credits, totalManaToTransfer);

        mana.forceApprove(address(offchainMarketplace), totalManaToTransfer);

        uint256 balanceBefore = mana.balanceOf(address(this));

        offchainMarketplace.accept(_trades);

        _validateResultingBalance(balanceBefore, totalManaToTransfer);

        _executeManaTransfers(manaToCredit, totalManaToTransfer);
    }

    function executeOffchainMarketplaceAcceptWithCoupon(
        MarketplaceWithCouponManager.Trade[] calldata _trades,
        MarketplaceWithCouponManager.Coupon[] calldata _coupons,
        Credit[] calldata _credits
    ) external {
        // Copy the trades to memory so _validateTrades can update the sent asset beneficiaries from address(0) to
        // the caller and prevent this contract from receiving the assets.
        MarketplaceWithCouponManager.Trade[] memory tradesWithUpdatedBeneficiaries = _trades;

        _validateTrades(tradesWithUpdatedBeneficiaries);

        // Copy the trades to memory again so the trades used in acceptWithCoupon are not affected by the next coupon
        // application used only to calculate total mana to transfer.
        MarketplaceWithCouponManager.Trade[] memory tradesWithCoupons = _trades;

        for (uint256 i = 0; i < _trades.length; i++) {
            address couponAddress = _coupons[i].couponAddress;

            // I don't need to check if the coupon address is valid because it is validated afterwards when calling
            // the marketplace.acceptWithCoupon function.
            ICoupon coupon = ICoupon(couponAddress);

            // Apply the coupon to the trade so the values are updated and can be used to calculate the total mana to transfer.
            tradesWithCoupons[i] = coupon.applyCoupon(tradesWithUpdatedBeneficiaries[i], _coupons[i]);
        }

        uint256 totalManaToTransfer = _computeTotalManaToTransfer(tradesWithCoupons);

        uint256 manaToCredit = _computeTotalManaToCredit(_credits, totalManaToTransfer);

        mana.forceApprove(address(offchainMarketplace), totalManaToTransfer);

        uint256 balanceBefore = mana.balanceOf(address(this));

        offchainMarketplace.acceptWithCoupon(tradesWithUpdatedBeneficiaries, _coupons);

        _validateResultingBalance(balanceBefore, totalManaToTransfer);

        _executeManaTransfers(manaToCredit, totalManaToTransfer);
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
                _validateContractAddress(sent[j].contractAddress);

                if (sent[j].assetType == ASSET_TYPE_ERC721) {
                    _validateSecondarySalesAllowed();
                } else if (sent[j].assetType == ASSET_TYPE_COLLECTION_ITEM) {
                    _validatePrimarySalesAllowed();
                } else {
                    revert("Invalid Sent Asset Type");
                }

                // If the beneficiary is address(0), it is updated to the caller to prevent this contract from receiving the assets.
                // This can be done because the sent asset beneficiary is not part of the Trade signature.
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
