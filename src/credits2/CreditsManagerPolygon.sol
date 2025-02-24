// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {CreditsManager} from "./CreditsManager.sol";
import {IMarketplace, Trade} from "./interfaces/IMarketplace.sol";
import {ICollectionStore} from "./interfaces/ICollectionStore.sol";
import {ILegacyMarketplace} from "./interfaces/ILegacyMarketplace.sol";
import {ICollectionFactory} from "./interfaces/ICollectionFactory.sol";
import {NativeMetaTransaction, EIP712} from "../common/NativeMetaTransaction.sol";

contract CreditsManagerPolygon is CreditsManager, NativeMetaTransaction {
    /// @notice The address of the Marketplace contract.
    address public immutable marketplace;

    /// @notice The address of the Legacy Marketplace contract.
    address public immutable legacyMarketplace;

    /// @notice The address of the CollectionStore contract.
    address public immutable collectionStore;

    /// @notice The address of the CollectionFactory contract.
    ICollectionFactory public immutable collectionFactory;

    /// @notice The address of the CollectionFactoryV3 contract.
    ICollectionFactory public immutable collectionFactoryV3;

    /// @notice The hash of the signatures of the Credits to be used for bids.
    bytes32 internal tempBidCreditsSignaturesHash;

    error NotDecentralandCollection(address _contractAddress);
    error ExternalCallFailed(ExternalCall _externalCall);
    error InvalidBeneficiary();
    error InvalidTrade(Trade _trade);
    error OnlyOneTradeAllowed();

    /// @param _init The base parameters for the CreditsManager.
    /// @param _marketplace The address of the Marketplace contract.
    /// @param _legacyMarketplace The address of the Legacy Marketplace contract.
    /// @param _collectionStore The address of the CollectionStore contract.
    /// @param _collectionFactory The address of the CollectionFactory contract.
    /// @param _collectionFactoryV3 The address of the CollectionFactoryV3 contract.
    constructor(
        Init memory _init,
        address _marketplace,
        address _legacyMarketplace,
        address _collectionStore,
        ICollectionFactory _collectionFactory,
        ICollectionFactory _collectionFactoryV3
    ) CreditsManager(_init) EIP712("CreditsManagerPolygon", "1.0.0") {
        marketplace = _marketplace;
        legacyMarketplace = _legacyMarketplace;
        collectionStore = _collectionStore;
        collectionFactory = _collectionFactory;
        collectionFactoryV3 = _collectionFactoryV3;

        _allowCall(marketplace, IMarketplace.accept.selector, true);
        _allowCall(marketplace, IMarketplace.acceptWithCoupon.selector, true);
        _allowCall(collectionStore, ICollectionStore.buy.selector, true);
        _allowCall(legacyMarketplace, ILegacyMarketplace.safeExecuteOrder.selector, true);
        _allowCall(legacyMarketplace, ILegacyMarketplace.executeOrder.selector, true);
    }

    /// @dev Implementation of the external call that will transfer mana for Decentraland Polygon Marketplaces.
    function _executeExternalCall(ExternalCall calldata _externalCall, bytes[] calldata _signatures)
        internal
        override
        returns (address creditsConsumer)
    {
        creditsConsumer = _msgSender();

        if (_externalCall.target == legacyMarketplace) {
            (address contractAddress) = abi.decode(_externalCall.data, (address));

            _verifyDecentralandCollection(contractAddress);
        }

        if (_externalCall.target == marketplace) {
            Trade[] memory trades = abi.decode(_externalCall.data, (Trade[]));

            if (trades.length != 1) {
                revert OnlyOneTradeAllowed();
            }

            Trade memory trade = trades[0];

            if (trade.received.length == 1 && trade.received[0].contractAddress == address(mana)) {
                // Valid listings are composed of trades in which only mana is received by the signer and only decentraland collections items or nfts are sent.
                for (uint256 j = 0; j < trade.sent.length; j++) {
                    _verifyDecentralandCollection(trade.sent[j].contractAddress);
                    // Address 0 is then converted to the address of the caller in the Marketplace contract for sent assets.
                    // The caller in this case is this contract.
                    // To prevent the asset to be received by this contract, we prevent callers from setting the beneficiary to address(0).
                    // Given that the sent beneficiary is not signed, it is easy for the caller to just set its own address to the beneficiary.
                    if (trade.sent[j].beneficiary == address(0)) {
                        revert InvalidBeneficiary();
                    }
                }
            } else if (trade.sent.length == 1 && trade.sent[0].contractAddress == address(mana)) {
                // Valid bids are composed of trades in which only decentraland collections items or nfts are received by the signer and only mana is sent.
                for (uint256 j = 0; j < trade.received.length; j++) {
                    _verifyDecentralandCollection(trade.received[j].contractAddress);
                }

                // The one who is using credits on bids is the one who signed the bid given that it is the one paying with mana.
                creditsConsumer = trade.signer;

                tempBidCreditsSignaturesHash = keccak256(abi.encode(_signatures));
            } else {
                revert InvalidTrade(trade);
            }
        }

        // Execute the external call.
        // The target and selector have already been verified on the CreditsManager base contract.
        (bool success,) = _externalCall.target.call(abi.encodeWithSelector(_externalCall.selector, _externalCall.data));

        if (!success) {
            revert ExternalCallFailed(_externalCall);
        }

        if (_externalCall.target == legacyMarketplace) {
            (address contractAddress, uint256 tokenId) = abi.decode(_externalCall.data, (address, uint256));

            // When an order is executed, the asset is transferred to the caller, which in this case is this contract.
            // We need to transfer the asset back to the user that is using the credits.
            IERC721(contractAddress).safeTransferFrom(address(this), creditsConsumer, tokenId);
        }

        if (_externalCall.target == marketplace) {
            if (tempBidCreditsSignaturesHash != bytes32(0)) {
                // To recover some gas after the bid has been executed, we reset the value back to default.
                delete tempBidCreditsSignaturesHash;
            }
        }
    }

    /// @notice Function used by the Marketplace to verify that the credits being used have been validated by the bid signer.
    /// @param _caller The address of the user that has called the Marketplace (Has to be this contract).
    /// @param _data The data of the external check (The hash of the signatures of the Credits to be used).
    function bidExternalCheck(address _caller, bytes calldata _data) external view returns (bool) {
        return _caller == address(this) && abi.decode(_data, (bytes32)) == tempBidCreditsSignaturesHash;
    }

    /// @dev This is used to prevent users from consuming credits on non-decentraland collections.
    function _verifyDecentralandCollection(address _contractAddress) internal view {
        if (!collectionFactory.isCollectionFromFactory(_contractAddress) && !collectionFactoryV3.isCollectionFromFactory(_contractAddress)) {
            revert NotDecentralandCollection(_contractAddress);
        }
    }

    /// @dev This is used to support meta transactions.
    function _msgSender() internal view override returns (address) {
        return _getMsgSender();
    }
}
