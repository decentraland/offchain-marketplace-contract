// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {EIP712} from "src/common/EIP712.sol";
import {IComposable} from "src/marketplace/interfaces/IComposable.sol";
import {MarketplaceWithCouponManager} from "src/marketplace/MarketplaceWithCouponManager.sol";
import {DecentralandMarketplaceEthereumAssetTypes} from "src/marketplace/DecentralandMarketplaceEthereumAssetTypes.sol";
import {FeeCollector} from "src/marketplace/FeeCollector.sol";
import {IAggregator} from "src/marketplace/interfaces/IAggregator.sol";
import {AggregatorHelper} from "src/marketplace/AggregatorHelper.sol";

/// @notice Decentraland Marketplace contract for the Ethereum network assets. MANA, LAND, Estates, Names, etc.
contract DecentralandMarketplaceEthereum is
    DecentralandMarketplaceEthereumAssetTypes,
    MarketplaceWithCouponManager,
    FeeCollector,
    AggregatorHelper
{
    /// @notice The MANA token address.
    /// @dev Used to transfer MANA tokens on for assets of type ASSET_TYPE_USD_PEGGED_MANA.
    address public immutable manaAddress;

    /// @notice The MANA/ETH price aggregator.
    /// @dev Used to obtain the price of MANA in ETH.
    IAggregator public manaEthAggregator;
    
    /// @notice The tolerance that indicates if the result provided by the aggregator is old.
    uint256 public manaEthAggregatorTolerance;

    /// @notice The ETH/USD price aggregator.
    /// @dev Used to obtain the price of ETH in USD.
    /// Along the manaEthAggregator result, we can calculate the price of MANA in USD.
    IAggregator public ethUsdAggregator;

    /// @notice The tolerance that indicates if the result provided by the aggregator is old.
    uint256 public ethUsdAggregatorTolerance;

    event ManaEthAggregatorUpdated(address indexed _aggregator, uint256 _tolerance);
    event EthUsdAggregatorUpdated(address indexed _aggregator, uint256 _tolerance);

    error InvalidFingerprint();

    /// @param _owner The owner of the contract.
    /// @param _couponManager The address of the coupon manager contract.
    /// @param _feeCollector The address that will receive erc20 fees.
    /// @param _feeRate The rate of the fee. 25_000 is 2.5%
    /// @param _manaAddress The address of the MANA token.
    /// @param _manaEthAggregator The address of the MANA/ETH price aggregator.
    /// @param _manaEthAggregatorTolerance The tolerance that indicates if the result provided by the aggregator is old.
    /// @param _ethUsdAggregator The address of the ETH/USD price aggregator.
    /// @param _ethUsdAggregatorTolerance The tolerance that indicates if the result provided by the aggregator is old.
    constructor(
        address _owner,
        address _couponManager,
        address _feeCollector,
        uint256 _feeRate,
        address _manaAddress,
        address _manaEthAggregator,
        uint256 _manaEthAggregatorTolerance,
        address _ethUsdAggregator,
        uint256 _ethUsdAggregatorTolerance
    )
        EIP712("DecentralandMarketplaceEthereum", "1.0.0")
        Ownable(_owner)
        MarketplaceWithCouponManager(_couponManager)
        FeeCollector(_feeCollector, _feeRate)
    {
        manaAddress = _manaAddress;

        _updateManaEthAggregator(_manaEthAggregator, _manaEthAggregatorTolerance);
        _updateEthUsdAggregator(_ethUsdAggregator, _ethUsdAggregatorTolerance);
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

    /// @notice Updates the MANA/ETH price aggregator and tolerance.
    /// @param _aggregator The new MANA/ETH price aggregator.
    /// @param _tolerance The new tolerance that indicates if the result provided by the aggregator is old.
    function updateManaEthAggregator(address _aggregator, uint256 _tolerance) external onlyOwner {
        _updateManaEthAggregator(_aggregator, _tolerance);
    }

    /// @notice Updates the ETH/USD price aggregator and tolerance.
    /// @param _aggregator The new ETH/USD price aggregator.
    /// @param _tolerance The new tolerance that indicates if the result provided by the aggregator is old.
    function updateEthUsdAggregator(address _aggregator, uint256 _tolerance) external onlyOwner {
        _updateEthUsdAggregator(_aggregator, _tolerance);
    }

    /// @dev Overriden Marketplace function to transfer assets.
    /// Handles the transfer of ERC20 and ERC721 assets.
    function _transferAsset(Asset memory _asset, address _from, address, address) internal override {
        uint256 assetType = _asset.assetType;

        if (assetType == ASSET_TYPE_ERC20) {
            _transferERC20(_asset, _from);
        } else if (assetType == ASSET_TYPE_USD_PEGGED_MANA) {
            _transferUsdPeggedMana(_asset, _from);
        } else if (assetType == ASSET_TYPE_ERC721) {
            _transferERC721(_asset, _from);
        } else {
            revert UnsupportedAssetType(assetType);
        }
    }

    /// @dev Transfers ERC20 assets to the beneficiary.
    /// A part of the value is taken as a fee and transferred to the fee collector.
    function _transferERC20(Asset memory _asset, address _from) internal {
        uint256 originalValue = _asset.value;
        uint256 fee = (originalValue * feeRate) / 1_000_000;

        IERC20 erc20 = IERC20(_asset.contractAddress);

        SafeERC20.safeTransferFrom(erc20, _from, _asset.beneficiary, originalValue - fee);
        SafeERC20.safeTransferFrom(erc20, _from, feeCollector, fee);
    }

    /// @dev Transfers ERC721 assets to the beneficiary.
    /// Takes into account Composable ERC721 contracts like Estates.
    function _transferERC721(Asset memory _asset, address _from) private {
        IComposable erc721 = IComposable(_asset.contractAddress);

        if (erc721.supportsInterface(erc721.verifyFingerprint.selector)) {
            bytes32 fingerprint = abi.decode(_asset.extra, (bytes32));

            if (!erc721.verifyFingerprint(_asset.value, abi.encode(fingerprint))) {
                revert InvalidFingerprint();
            }
        }

        erc721.safeTransferFrom(_from, _asset.beneficiary, _asset.value);
    }

    /// @dev Transfers MANA to the beneficiary depending to the provided value in USD defined in the asset.
    function _transferUsdPeggedMana(Asset memory _asset, address _from) private {
        // Obtains the price of MANA in ETH.
        int256 manaEthRate = _getRateFromAggregator(manaEthAggregator, manaEthAggregatorTolerance);

        // Obtains the price of ETH in USD.
        int256 ethUsdRate = _getRateFromAggregator(ethUsdAggregator, ethUsdAggregatorTolerance);

        // With the obtained rates, we can calculate the price of MANA in USD.
        int256 manaUsdRate = (manaEthRate * ethUsdRate) / 1e18;

        // Updates the asset with the new values.
        _asset = _updateAssetWithConvertedMANAPrice(_asset, manaAddress, manaUsdRate);

        // With the updated asset, we can perform a normal ERC20 transfer.
        _transferERC20(_asset, _from);
    }

    /// @dev Updates the MANA/ETH price aggregator and tolerance.
    function _updateManaEthAggregator(address _aggregator, uint256 _tolerance) private {
        manaEthAggregator = IAggregator(_aggregator);
        manaEthAggregatorTolerance = _tolerance;

        emit ManaEthAggregatorUpdated(_aggregator, _tolerance);
    }

    /// @dev Updates the ETH/USD price aggregator and tolerance.
    function _updateEthUsdAggregator(address _aggregator, uint256 _tolerance) private {
        ethUsdAggregator = IAggregator(_aggregator);
        ethUsdAggregatorTolerance = _tolerance;

        emit EthUsdAggregatorUpdated(_aggregator, _tolerance);
    }
}
