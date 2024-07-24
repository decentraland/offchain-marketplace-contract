// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {EIP712} from "src/common/EIP712.sol";
import {NativeMetaTransaction} from "src/common/NativeMetaTransaction.sol";
import {ICollection} from "src/marketplace/interfaces/ICollection.sol";
import {MarketplaceWithCouponManager} from "src/marketplace/MarketplaceWithCouponManager.sol";
import {DecentralandMarketplacePolygonAssetTypes} from "src/marketplace/DecentralandMarketplacePolygonAssetTypes.sol";
import {IRoyaltiesManager} from "src/marketplace/interfaces/IRoyaltiesManager.sol";
import {FeeCollector} from "src/marketplace/FeeCollector.sol";
import {IAggregator} from "src/marketplace/interfaces/IAggregator.sol";
import {AggregatorHelper} from "src/marketplace/AggregatorHelper.sol";

/// @notice Decentraland Marketplace contract for the Polygon network assets. MANA, Wearables, Emotes, etc.
contract DecentralandMarketplacePolygon is
    DecentralandMarketplacePolygonAssetTypes,
    MarketplaceWithCouponManager,
    NativeMetaTransaction,
    FeeCollector,
    AggregatorHelper
{
    /// @notice The address of the MANA ERC20 contract.
    /// @dev This will be used when transferring USD pegged MANA by enforcing this address as the Asset's contract address.
    address public immutable manaAddress;

    /// @notice The MANA/USD Chainlink aggregator.
    /// @dev Used to obtain the rate of MANA expressed in USD.
    IAggregator public manaUsdAggregator;

    /// @notice Maximum time (in seconds) since the MANA/USD aggregator result was last updated before it is considered outdated.
    uint256 public manaUsdAggregatorTolerance;

    /// @notice The royalties manager contract. Used to get the royalties receiver for collection nft trades.
    IRoyaltiesManager public royaltiesManager;

    /// @notice The rate of the royalties to be sent to the royalties receiver.
    uint256 public royaltiesRate;

    event RoyaltiesManagerUpdated(address indexed _caller, address indexed _royaltiesManager);
    event RoyaltiesRateUpdated(address indexed _caller, uint256 _royaltiesRate);
    event ManaUsdAggregatorUpdated(address indexed _aggregator, uint256 _tolerance);

    error NotCreator();

    /// @param _owner The owner of the contract.
    /// @param _couponManager The address of the coupon manager contract.
    /// @param _feeCollector The address that will receive erc20 fees.
    /// @param _feeRate The rate of the fee. 25_000 is 2.5%
    /// @param _royaltiesManager The address of the royalties manager contract.
    /// @param _royaltiesRate The rate of the royalties. 25_000 is 2.5%
    /// @param _manaAddress The address of the MANA token.
    /// @param _manaUsdAggregator The address of the MANA/USD price aggregator.
    /// @param _manaUsdAggregatorTolerance The tolerance (in seconds) that indicates if the result provided by the aggregator is old.
    constructor(
        address _owner,
        address _couponManager,
        address _feeCollector,
        uint256 _feeRate,
        address _royaltiesManager,
        uint256 _royaltiesRate,
        address _manaAddress,
        address _manaUsdAggregator,
        uint256 _manaUsdAggregatorTolerance
    )
        FeeCollector(_feeCollector, _feeRate)
        EIP712("DecentralandMarketplacePolygon", "1.0.0")
        Ownable(_owner)
        MarketplaceWithCouponManager(_couponManager)
    {
        _updateRoyaltiesManager(_royaltiesManager);
        _updateRoyaltiesRate(_royaltiesRate);

        manaAddress = _manaAddress;

        _updateManaUsdAggregator(_manaUsdAggregator, _manaUsdAggregatorTolerance);
    }

    /// @notice Updates the fee collector address.
    /// @param _feeCollector The new fee collector address.
    function updateFeeCollector(address _feeCollector) external onlyOwner {
        _updateFeeCollector(_msgSender(), _feeCollector);
    }

    /// @notice Updates the fee rate.
    /// @param _feeRate The new fee rate.
    function updateFeeRate(uint256 _feeRate) external onlyOwner {
        _updateFeeRate(_msgSender(), _feeRate);
    }

    /// @notice Updates the royalties manager address.
    /// @param _royaltiesManager The new royalties manager address.
    function updateRoyaltiesManager(address _royaltiesManager) external onlyOwner {
        _updateRoyaltiesManager(_royaltiesManager);
    }

    /// @notice Updates the royalties rate.
    /// @param _royaltiesRate The new royalties rate.
    function updateRoyaltiesRate(uint256 _royaltiesRate) external onlyOwner {
        _updateRoyaltiesRate(_royaltiesRate);
    }

    /// @notice Updates the MANA/USD price aggregator and tolerance.
    /// @param _aggregator The new MANA/USD price aggregator.
    /// @param _tolerance The new tolerance that indicates if the result provided by the aggregator is old.
    function updateManaUsdAggregator(address _aggregator, uint256 _tolerance) external onlyOwner {
        _updateManaUsdAggregator(_aggregator, _tolerance);
    }

    /// @dev Overridden Marketplace function which modifies the Trade before being accepted.
    /// In this case, the Trade is modified to handle fees and royalties.
    function _modifyTrade(Trade memory _trade) internal view override {
        // Tracks if the fee collector should be paid.
        bool payFeeCollector = false;
        // Tracks the number of addresses that have to be paid royalties.
        uint256 royaltyBeneficiariesCount = 0;
        // Tracks the addresses that have to be paid royalties.
        address[] memory royaltyBeneficiaries = new address[](_trade.sent.length + _trade.received.length);

        // Obtain if the fee collector has to be paid, the amount of royalty beneficiaries to be paid, and the addresses of the royalty beneficiaries.
        (payFeeCollector, royaltyBeneficiariesCount) = _getFeesAndRoyalties(payFeeCollector, royaltyBeneficiariesCount, royaltyBeneficiaries, _trade.sent);
        (payFeeCollector, royaltyBeneficiariesCount) = _getFeesAndRoyalties(payFeeCollector, royaltyBeneficiariesCount, royaltyBeneficiaries, _trade.received);

        // Encodes the fees and royalties data to be stored in the assets.
        bytes memory encodedFeeAndRoyaltyData = abi.encode(payFeeCollector, royaltyBeneficiariesCount, royaltyBeneficiaries);

        // Update erc20 assets to include fee and royalties data.
        _updateERC20sWithFees(_trade.sent, encodedFeeAndRoyaltyData);
        _updateERC20sWithFees(_trade.received, encodedFeeAndRoyaltyData);
    }

    /// @dev From the provided assets, returns if the fee collector should be paid and the respective royalties beneficiaries.
    /// Updates the provided royalty beneficiaries array with the new values.
    function _getFeesAndRoyalties(
        bool _payFeeCollector,
        uint256 _royaltyBeneficiariesCount,
        address[] memory _royaltyBeneficiaries,
        Asset[] memory _assets
    ) private view returns (bool, uint256) {
        for (uint256 i = 0; i < _assets.length; i++) {
            Asset memory asset = _assets[i];

            if (asset.assetType == ASSET_TYPE_ERC721) {
                // If the NFT is of a Decentraland Collection, the royalty beneficiary will be the item beneficiary or its creator.
                // If not, the royalty beneficiary will return address(0)
                address royaltyBeneficiary = royaltiesManager.getRoyaltiesReceiver(asset.contractAddress, asset.value);

                if (royaltyBeneficiary != address(0)) {
                    _royaltyBeneficiaries[_royaltyBeneficiariesCount++] = royaltyBeneficiary;
                } else {
                    // If the NFT is not a Decentraland Collection, the fee collector should be paid.
                    _payFeeCollector = true;
                }
            } else if (asset.assetType == ASSET_TYPE_COLLECTION_ITEM) {
                // Minting Collection Items pay fees to the collector.
                _payFeeCollector = true;
            }
        }

        return (_payFeeCollector, _royaltyBeneficiariesCount);
    }

    /// @dev Iterate through the provided assets and update the ERC20 assets to include the fees and royalties data.
    /// Also handles USD pegged MANA by updating the asset values to the proper amount of MANA.
    function _updateERC20sWithFees(Asset[] memory _assets, bytes memory _encodedFeeAndRoyaltyData) private view {
        for (uint256 i = 0; i < _assets.length; i++) {
            uint256 assetType = _assets[i].assetType;

            // These assets have the value in USD, and have to be converted to MANA.
            if (assetType == ASSET_TYPE_USD_PEGGED_MANA) {
                // Obtains the price of MANA in USD.
                int256 manaUsdRate = _getRateFromAggregator(manaUsdAggregator, manaUsdAggregatorTolerance);

                // Updates the asset with the new values.
                _updateAssetWithConvertedMANAPrice(_assets[i], manaAddress, manaUsdRate);
            }

            // Add the fees and royalties data to the erc20 asset.
            if (assetType == ASSET_TYPE_ERC20 || assetType == ASSET_TYPE_USD_PEGGED_MANA) {
                _assets[i].extra = _encodedFeeAndRoyaltyData;
            }
        }
    }

    /// @dev Overridden Marketplace function to transfer assets.
    /// Handles the transfer of ERC721s and the minting of Collection Items. Also handles the transfer of ERC20s with fees.
    function _transferAsset(Asset memory _asset, address _from, address _signer, address _caller) internal override {
        uint256 assetType = _asset.assetType;

        if (assetType == ASSET_TYPE_ERC20 || assetType == ASSET_TYPE_USD_PEGGED_MANA) {
            _transferERC20WithFees(_asset, _from);
        } else if (assetType == ASSET_TYPE_ERC721) {
            _transferERC721(_asset, _from);
        } else if (assetType == ASSET_TYPE_COLLECTION_ITEM) {
            _transferERC721CollectionItem(_asset, _signer, _caller);
        } else {
            revert UnsupportedAssetType(assetType);
        }
    }

    /// @dev Transfers ERC20 assets with fees and royalties.
    /// The fees are included in the `extra` asset data and were set in the `_modifyTrade` function.
    function _transferERC20WithFees(Asset memory _asset, address _from) private {
        // Get the fee data from the `extra` field.
        (bool payFeeCollector, uint256 royaltyBeneficiariesCount, address[] memory royaltyBeneficiaries) =
            abi.decode(_asset.extra, (bool, uint256, address[]));

        uint256 originalValue = _asset.value;
        // Track the total amount of fees and royalties to be paid.
        uint256 fees = 0;

        IERC20 erc20 = IERC20(_asset.contractAddress);

        // If the fee collector has to be paid, calculate the fee and transfer it.
        // Checking for 0 royalty beneficiaries is to pay the fee collector on cases in which the Trade only swaps ERC20s.
        // This is to have the same behavior on both the Ethereum and Polygon Marketplace contracts.
        if (payFeeCollector || royaltyBeneficiariesCount == 0) {
            fees = originalValue * feeRate / 1_000_000;

            SafeERC20.safeTransferFrom(erc20, _from, feeCollector, fees);
        }

        // If there are royalties to be paid, calculate the royalties and transfer them.
        if (royaltyBeneficiariesCount > 0) {
            uint256 royaltyFees = originalValue * royaltiesRate / 1_000_000;
            uint256 individualRoyaltyFee = royaltyFees / royaltyBeneficiariesCount;

            for (uint256 i = 0; i < royaltyBeneficiariesCount; i++) {
                SafeERC20.safeTransferFrom(erc20, _from, royaltyBeneficiaries[i], individualRoyaltyFee);
            }

            fees += royaltyFees;
        }

        SafeERC20.safeTransferFrom(erc20, _from, _asset.beneficiary, originalValue - fees);
    }

    /// @dev Transfers ERC721 assets.
    function _transferERC721(Asset memory _asset, address _from) private {
        IERC721(_asset.contractAddress).safeTransferFrom(_from, _asset.beneficiary, _asset.value);
    }

    /// @dev Mints collection items.
    function _transferERC721CollectionItem(Asset memory _asset, address _signer, address _caller) private {
        ICollection collection = ICollection(_asset.contractAddress);

        address creator = collection.creator();

        // This check verifies that at least the caller or the signer have to be the creator.
        // This allows the following:
        // 1. The creator creates a Trade to sell a collection item. Any user can accept the Trade and it will be valid.
        // 2. Any user creates a counter offer to buy a collection item. Only the creator should be able to accept the Trade.
        if (creator != _signer && creator != _caller) {
            revert NotCreator();
        }

        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = _asset.beneficiary;

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = _asset.value;

        collection.issueTokens(beneficiaries, itemIds);
    }

    /// @dev Updates the royalties manager address.
    /// @param _royaltiesManager The new royalties manager address.
    function _updateRoyaltiesManager(address _royaltiesManager) private {
        royaltiesManager = IRoyaltiesManager(_royaltiesManager);

        emit RoyaltiesManagerUpdated(_msgSender(), _royaltiesManager);
    }

    /// @dev Updates the royalties rate.
    /// @param _royaltiesRate The new royalties rate.
    function _updateRoyaltiesRate(uint256 _royaltiesRate) private {
        royaltiesRate = _royaltiesRate;

        emit RoyaltiesRateUpdated(_msgSender(), _royaltiesRate);
    }

    /// @dev Updates the MANA/USD price aggregator and tolerance.
    function _updateManaUsdAggregator(address _aggregator, uint256 _tolerance) private {
        manaUsdAggregator = IAggregator(_aggregator);
        manaUsdAggregatorTolerance = _tolerance;

        emit ManaUsdAggregatorUpdated(_aggregator, _tolerance);
    }

    /// @dev Overridden function to obtain the caller of the transaction.
    /// The contract accepts meta transactions, so the caller could be the signer of the meta transaction or the real caller depending on the situation.
    function _msgSender() internal view override returns (address) {
        return _getMsgSender();
    }
}
