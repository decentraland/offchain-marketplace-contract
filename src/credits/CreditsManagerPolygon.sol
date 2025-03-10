// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {NativeMetaTransaction, EIP712} from "src/common/NativeMetaTransaction.sol";
import {IMarketplace} from "src/credits/interfaces/IMarketplace.sol";
import {ILegacyMarketplace} from "src/credits/interfaces/ILegacyMarketplace.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";
import {ICollectionStore} from "src/credits/interfaces/ICollectionStore.sol";

contract CreditsManagerPolygon is AccessControl, Pausable, ReentrancyGuard, NativeMetaTransaction, IERC721Receiver {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    /// @notice The role that can sign credits.
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    /// @notice The role that can pause the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice The role that can deny users from using credits.
    bytes32 public constant DENIER_ROLE = keccak256("DENIER_ROLE");

    /// @notice The role that can revoke credits.
    bytes32 public constant REVOKER_ROLE = keccak256("REVOKER_ROLE");

    /// @notice The role that can sign external calls.
    bytes32 public constant EXTERNAL_CALL_SIGNER_ROLE = keccak256("EXTERNAL_CALL_SIGNER_ROLE");

    /// @notice The role that can revoke external calls.
    bytes32 public constant EXTERNAL_CALL_REVOKER_ROLE = keccak256("EXTERNAL_CALL_REVOKER_ROLE");

    /// @notice Asset type for ERC20 tokens for the Marketplace Trade struct.
    uint256 public constant ASSET_TYPE_ERC20 = 1;

    /// @notice Asset type for USD pegged MANA for the Marketplace Trade struct.
    uint256 public constant ASSET_TYPE_USD_PEGGED_MANA = 2;

    /// @notice Asset type for NFTs for the Marketplace Trade struct.
    uint256 public constant ASSET_TYPE_ERC721 = 3;

    /// @notice Asset type for collection items for the Marketplace Trade struct.
    uint256 public constant ASSET_TYPE_COLLECTION_ITEM = 4;

    /// @notice Whether a user is denied from using credits.
    mapping(address => bool) public isDenied;

    /// @notice Whether a credit has been revoked.
    /// @dev The key is the hash of the credit signature.
    mapping(bytes32 => bool) public isRevoked;

    /// @notice The address of the MANA token.
    IERC20 public immutable mana;

    /// @notice The amount of MANA value used on each credit.
    /// @dev The key is the hash of the credit signature.
    mapping(bytes32 => uint256) public spentValue;

    /// @notice Maximum amount of MANA that can be credited per hour.
    uint256 public maxManaCreditedPerHour;

    /// @notice How much MANA has been credited this hour.
    uint256 public manaCreditedThisHour;

    /// @notice The hour of the last MANA credit.
    uint256 public hourOfLastManaCredit;

    /// @notice Whether primary sales are allowed.
    bool public primarySalesAllowed;

    /// @notice Whether secondary sales are allowed.
    bool public secondarySalesAllowed;

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

    /// @notice Tracks the allowed custom external calls.
    mapping(address => mapping(bytes4 => bool)) public allowedCustomExternalCalls;

    /// @notice Tracks the used external call signatures.
    mapping(bytes32 => bool) public usedCustomExternalCallSignature;

    /// @notice The roles to initialize the contract with.
    /// @param owner The address that acts as default admin.
    /// @param signer The address that can sign credits.
    /// @param pauser The address that can pause the contract.
    /// @param denier The address that can deny users from using credits.
    /// @param revoker The address that can revoke credits.
    /// @param customExternalCallSigner The address that can sign custom external calls.
    /// @param customExternalCallRevoker The address that can revoke custom external calls.
    struct Roles {
        address owner;
        address signer;
        address pauser;
        address denier;
        address revoker;
        address customExternalCallSigner;
        address customExternalCallRevoker;
    }

    /// @notice The arguments for the useCredits function.
    /// @param credits The credits to use.
    /// @param creditsSignatures The signatures of the credits.
    /// Has to be signed by a wallet that has the signer role.
    /// @param externalCall The external call to make.
    /// @param customExternalCallSignature The signature of the external call.
    /// Only used for custom external calls.
    /// Has to be signed by a wallet that has the customExternalCallSigner role.
    /// @param maxUncreditedValue The maximum amount of MANA the user is willing to pay from their wallet when credits are insufficient to cover the total transaction cost.
    /// @param maxCreditedValue The maximum amount of MANA that can be credited from the provided credits.
    struct UseCreditsArgs {
        Credit[] credits;
        bytes[] creditsSignatures;
        ExternalCall externalCall;
        bytes customExternalCallSignature;
        uint256 maxUncreditedValue;
        uint256 maxCreditedValue;
    }

    /// @param value How much ERC20 the credit is worth.
    /// @param expiresAt The timestamp when the credit expires.
    /// @param salt Value used to generate unique credits.
    struct Credit {
        uint256 value;
        uint256 expiresAt;
        bytes32 salt;
    }

    /// @param target The contract address of the external call.
    /// @param selector The selector of the external call.
    /// @param data The data of the external call.
    /// @param expiresAt The timestamp when the external call expires.
    /// Only used for custom external calls.
    /// @param salt The salt of the external call.
    /// Only used for custom external calls.
    struct ExternalCall {
        address target;
        bytes4 selector;
        bytes data;
        uint256 expiresAt;
        bytes32 salt;
    }

    event UserDenied(address indexed _user);
    event UserAllowed(address indexed _user);
    event CreditRevoked(bytes32 indexed _creditId);
    event ERC20Withdrawn(address indexed _token, uint256 _amount, address indexed _to);
    event ERC721Withdrawn(address indexed _token, uint256 _tokenId, address indexed _to);
    event CustomExternalCallAllowed(address indexed _target, bytes4 indexed _selector, bool _allowed);
    event CustomExternalCallRevoked(bytes32 indexed _hashedExternalCallSignature);
    event CreditUsed(bytes32 indexed _creditId, Credit _credit, uint256 _value);
    event CreditsUsed(uint256 _manaTransferred, uint256 _creditedValue);
    event MaxManaCreditedPerHourUpdated(uint256 _maxManaCreditedPerHour);
    event PrimarySalesAllowedUpdated(bool _primarySalesAllowed);
    event SecondarySalesAllowedUpdated(bool _secondarySalesAllowed);

    error DeniedUser(address _user);
    error InvalidExternalCallSelector(address _target, bytes4 _selector);
    error SecondarySalesNotAllowed();
    error InvalidTradesLength();
    error InvalidTrade(IMarketplace.Trade _trade);
    error InvalidAssetsLength();
    error PrimarySalesNotAllowed();
    error InvalidBeneficiary();
    error CustomExternalCallNotAllowed(address _target, bytes4 _selector);
    error CustomExternalCallExpired(uint256 _expiresAt);
    error UsedCustomExternalCallSignature(bytes32 _hashedCustomExternalCallSignature);
    error InvalidCustomExternalCallSignature(address _recoveredSigner);
    error ExternalCallFailed(ExternalCall _externalCall);
    error NoMANATransfer();
    error NoCredits();
    error InvalidCreditsSignaturesLength();
    error MaxCreditedValueZero();
    error InvalidCreditValue();
    error CreditExpired(bytes32 _creditId);
    error RevokedCredit(bytes32 _creditId);
    error InvalidSignature(bytes32 _creditId, address _recoveredSigner);
    error CreditConsumed(bytes32 _creditId);
    error MaxCreditedValueExceeded(uint256 _creditedValue, uint256 _maxCreditedValue);
    error MaxManaCreditedPerHourExceeded(uint256 _creditableManaThisHour, uint256 _creditedValue);
    error MaxUncreditedValueExceeded(uint256 _uncreditedValue, uint256 _maxUncreditedValue);
    error NotDecentralandCollection(address _contractAddress);

    /// @param _roles The roles to initialize the contract with.
    /// @param _maxManaCreditedPerHour The maximum amount of MANA that can be credited per hour.
    /// @param _primarySalesAllowed Whether primary sales are allowed.
    /// @param _secondarySalesAllowed Whether secondary sales are allowed.
    /// @param _mana The MANA token.
    /// @param _marketplace The Marketplace contract.
    /// @param _legacyMarketplace The Legacy Marketplace contract.
    /// @param _collectionStore The CollectionStore contract.
    /// @param _collectionFactory The CollectionFactory contract.
    /// @param _collectionFactoryV3 The CollectionFactoryV3 contract.
    constructor(
        Roles memory _roles,
        uint256 _maxManaCreditedPerHour,
        bool _primarySalesAllowed,
        bool _secondarySalesAllowed,
        IERC20 _mana,
        address _marketplace,
        address _legacyMarketplace,
        address _collectionStore,
        ICollectionFactory _collectionFactory,
        ICollectionFactory _collectionFactoryV3
    ) EIP712("Decentraland Credits", "1.0.0") {
        _grantRole(DEFAULT_ADMIN_ROLE, _roles.owner);

        _grantRole(SIGNER_ROLE, _roles.signer);

        _grantRole(PAUSER_ROLE, _roles.pauser);
        _grantRole(PAUSER_ROLE, _roles.owner);

        _grantRole(DENIER_ROLE, _roles.denier);
        _grantRole(DENIER_ROLE, _roles.owner);

        _grantRole(REVOKER_ROLE, _roles.revoker);
        _grantRole(REVOKER_ROLE, _roles.owner);

        _grantRole(EXTERNAL_CALL_SIGNER_ROLE, _roles.customExternalCallSigner);

        _grantRole(EXTERNAL_CALL_REVOKER_ROLE, _roles.customExternalCallRevoker);
        _grantRole(EXTERNAL_CALL_REVOKER_ROLE, _roles.owner);

        _updateMaxManaCreditedPerHour(_maxManaCreditedPerHour);

        _updatePrimarySalesAllowed(_primarySalesAllowed);
        _updateSecondarySalesAllowed(_secondarySalesAllowed);

        mana = _mana;
        marketplace = _marketplace;
        legacyMarketplace = _legacyMarketplace;
        collectionStore = _collectionStore;
        collectionFactory = _collectionFactory;
        collectionFactoryV3 = _collectionFactoryV3;
    }

    /// @notice Pauses the contract.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpauses the contract.
    /// @dev Only the owner can unpause the contract.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Denies a user from using credits.
    /// @param _user The user to deny.
    function denyUser(address _user) external onlyRole(DENIER_ROLE) {
        isDenied[_user] = true;

        emit UserDenied(_user);
    }

    /// @notice Allows a user to use credits.
    /// @dev Only the owner can allow a user to use credits.
    /// @dev All users are allowed by default.
    /// @param _user The user to allow.
    function allowUser(address _user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isDenied[_user] = false;

        emit UserAllowed(_user);
    }

    /// @notice Revokes a credit.
    /// @param _credit The hash of the credit signature.
    function revokeCredit(bytes32 _credit) external onlyRole(REVOKER_ROLE) {
        isRevoked[_credit] = true;

        emit CreditRevoked(_credit);
    }

    /// @notice Update the maximum amount of MANA that can be credited per hour.
    /// @param _maxManaCreditedPerHour The new maximum amount of MANA that can be credited per hour.
    function updateMaxManaCreditedPerHour(uint256 _maxManaCreditedPerHour) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateMaxManaCreditedPerHour(_maxManaCreditedPerHour);
    }

    /// @notice Update whether primary sales are allowed.
    /// @param _primarySalesAllowed Whether primary sales are allowed.
    function updatePrimarySalesAllowed(bool _primarySalesAllowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updatePrimarySalesAllowed(_primarySalesAllowed);
    }

    /// @notice Update whether secondary sales are allowed.
    /// @param _secondarySalesAllowed Whether secondary sales are allowed.
    function updateSecondarySalesAllowed(bool _secondarySalesAllowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateSecondarySalesAllowed(_secondarySalesAllowed);
    }

    /// @notice Withdraw ERC20 tokens from the contract.
    /// @param _token The address of the ERC20 token.
    /// @param _amount The amount of ERC20 tokens to withdraw.
    /// @param _to The address to send the ERC20 tokens to.
    function withdrawERC20(address _token, uint256 _amount, address _to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(_token).safeTransfer(_to, _amount);

        emit ERC20Withdrawn(_token, _amount, _to);
    }

    /// @notice Withdraw ERC721 tokens from the contract.
    /// @param _token The address of the ERC721 token.
    /// @param _tokenId The ID of the ERC721 token.
    /// @param _to The address to send the ERC721 token to.
    function withdrawERC721(address _token, uint256 _tokenId, address _to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC721(_token).safeTransferFrom(address(this), _to, _tokenId);

        emit ERC721Withdrawn(_token, _tokenId, _to);
    }

    /// @notice Allows a custom external call.
    /// @param _target The target of the external call.
    /// @param _selector The selector of the external call.
    /// @param _allowed Whether the external call is allowed.
    function allowCustomExternalCall(address _target, bytes4 _selector, bool _allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allowedCustomExternalCalls[_target][_selector] = _allowed;

        emit CustomExternalCallAllowed(_target, _selector, _allowed);
    }

    /// @notice Revokes a custom external call.
    /// @param _hashedCustomExternalCallSignature The hash of the custom external call signature.
    function revokeCustomExternalCall(bytes32 _hashedCustomExternalCallSignature) external onlyRole(EXTERNAL_CALL_REVOKER_ROLE) {
        usedCustomExternalCallSignature[_hashedCustomExternalCallSignature] = true;

        emit CustomExternalCallRevoked(_hashedCustomExternalCallSignature);
    }

    /// @notice Use credits to pay for external calls that transfer MANA.
    /// @param _args The arguments for the useCredits function.
    ///
    /// NOTE: There is a current issue with Marketplace bids where MANA is consumed from the bid signer
    /// rather than the caller interacting with the contract. This creates accounting discrepancies
    /// and requires special handling for bids. At present, the contract does not fully support
    /// marketplace bids correctly.
    function useCredits(UseCreditsArgs calldata _args) external nonReentrant whenNotPaused {
        address sender = _msgSender();

        // Handle pre-execution checks for the different types of external calls.
        _handlePreExecution(_args, sender);

        // Execute the external call and get the amount of MANA that was transferred out of the contract.
        uint256 manaTransferred = _executeExternalCall(_args, sender);

        // Handle post-execution checks.
        _handlePostExecution(_args, sender);

        // Validate and get how much MANA will be credited by the credits.
        uint256 creditedValue = _validateAndApplyCredits(_args, sender, manaTransferred);

        // Perform different checks on the credited value obtained.
        _validateCreditedValue(_args, creditedValue);

        // Calculate how much mana was not covered by credits.
        uint256 uncredited = manaTransferred - creditedValue;

        // Perform different checks on the uncredited value.
        // Transfer any exceeding amount extracted from the caller's wallet back to them.
        _handleUncreditedValue(_args, uncredited, sender);
    }

    /// @notice Allows the contract to receive ERC721 tokens.
    /// @dev Required for the Legacy Marketplace to work given that the purchased asset is transferred to this contract.
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // -----------------------------------------------------------------------------------------------------------------
    // ------------------------------ PRE EXECUTION FUNCTIONS ----------------------------------------------------------
    // -----------------------------------------------------------------------------------------------------------------

    /// @dev Handles all checks that need to be done before executing the external call.
    /// @param _args The arguments for the useCredits function.
    /// @param _sender The caller of the `useCredits` function.
    function _handlePreExecution(UseCreditsArgs calldata _args, address _sender) internal {
        // Check if the sender has been denied from using credits.
        if (isDenied[_sender]) {
            revert DeniedUser(_sender);
        }

        if (_args.externalCall.target == legacyMarketplace) {
            _handleLegacyMarketplacePreExecution(_args);
        } else if (_args.externalCall.target == marketplace) {
            _handleMarketplacePreExecution(_args);
        } else if (_args.externalCall.target == collectionStore) {
            _handleCollectionStorePreExecution(_args);
        } else {
            _handleCustomExternalCallPreExecution(_args);
        }
    }

    /// @dev Handles all checks that need to be done before executing the external call for the Legacy Marketplace.
    /// @param _args The arguments for the useCredits function.
    function _handleLegacyMarketplacePreExecution(UseCreditsArgs calldata _args) internal view {
        // Check that only executeOrder is being called.
        if (_args.externalCall.selector != ILegacyMarketplace.executeOrder.selector) {
            revert InvalidExternalCallSelector(_args.externalCall.target, _args.externalCall.selector);
        }

        // Secondary sales have to be allowed.
        if (!secondarySalesAllowed) {
            revert SecondarySalesNotAllowed();
        }

        // Decode the contract address from the data
        (address contractAddress) = abi.decode(_args.externalCall.data, (address));

        // Check that the sent assets are decentraland collections items or nfts.
        _verifyDecentralandCollection(contractAddress);
    }

    /// @dev Handles all checks that need to be done before executing the external call for the Marketplace.
    /// @param _args The arguments for the useCredits function.
    function _handleMarketplacePreExecution(UseCreditsArgs memory _args) internal view {
        // Cache these flags to prevent multiple storage reads.
        bool memPrimarySalesAllowed = primarySalesAllowed;
        bool memSecondarySalesAllowed = secondarySalesAllowed;

        // Check that only accept or acceptWithCoupon are being called.
        if (_args.externalCall.selector != IMarketplace.accept.selector && _args.externalCall.selector != IMarketplace.acceptWithCoupon.selector) {
            revert InvalidExternalCallSelector(_args.externalCall.target, _args.externalCall.selector);
        }

        // Decode the trades from the data.
        IMarketplace.Trade[] memory trades = abi.decode(_args.externalCall.data, (IMarketplace.Trade[]));

        // Check that there is at least one trade.
        if (trades.length == 0) {
            revert InvalidTradesLength();
        }

        for (uint256 i = 0; i < trades.length; i++) {
            IMarketplace.Trade memory trade = trades[i];

            // We have to check if the trade is a valid listing.
            // A valid listing is composed of:
            // - 1 mana asset received by the signer.
            // - n amount of decentraland assets sent to the caller.
            //
            // First we check that the received assets are composed of only 1 mana asset.
            if (
                trade.received.length != 1 || trade.received[0].contractAddress != address(mana)
                    || (trade.received[0].assetType != ASSET_TYPE_ERC20 && trade.received[0].assetType != ASSET_TYPE_USD_PEGGED_MANA)
            ) {
                revert InvalidTrade(trade);
            }

            // Then we check that there is at least one sent asset.
            if (trade.sent.length == 0) {
                revert InvalidAssetsLength();
            }

            for (uint256 j = 0; j < trade.sent.length; j++) {
                IMarketplace.Asset memory asset = trade.sent[j];

                // We check that the sent assets are decentraland collections items or nfts.
                _verifyDecentralandCollection(asset.contractAddress);

                // Depending on the asset type we check if primary sales or secondary sales are allowed.
                //
                // For NFTs, secondary sales have to be allowed.
                if (asset.assetType == ASSET_TYPE_ERC721 && !memSecondarySalesAllowed) {
                    revert SecondarySalesNotAllowed();
                }

                // For collection items, primary sales have to be allowed.
                if (asset.assetType == ASSET_TYPE_COLLECTION_ITEM && !memPrimarySalesAllowed) {
                    revert PrimarySalesNotAllowed();
                }

                // We check that the beneficiary was not set to 0 to prevent this contract from receiving the asset.
                if (asset.beneficiary == address(0)) {
                    revert InvalidBeneficiary();
                }
            }
        }
    }

    /// @dev Handles all checks that need to be done before executing the external call for the Collection Store.
    /// @param _args The arguments for the useCredits function.
    function _handleCollectionStorePreExecution(UseCreditsArgs calldata _args) internal view {
        // Check that only buy is being called.
        if (_args.externalCall.selector != ICollectionStore.buy.selector) {
            revert InvalidExternalCallSelector(_args.externalCall.target, _args.externalCall.selector);
        }

        if (!primarySalesAllowed) {
            revert PrimarySalesNotAllowed();
        }

        // Decode the items to buy from the data.
        ICollectionStore.ItemToBuy[] memory itemsToBuy = abi.decode(_args.externalCall.data, (ICollectionStore.ItemToBuy[]));

        // We check that there is at least one item to buy.
        if (itemsToBuy.length == 0) {
            revert InvalidAssetsLength();
        }

        for (uint256 i = 0; i < itemsToBuy.length; i++) {
            ICollectionStore.ItemToBuy memory itemToBuy = itemsToBuy[i];

            // We check that the collection has been created by a CollectionFactory and has not been deployed randomly by a malicious actor.
            _verifyDecentralandCollection(itemToBuy.collection);
        }
    }

    /// @dev Handles all checks that need to be done before executing the external call for a custom external call.
    /// @param _args The arguments for the useCredits function.
    function _handleCustomExternalCallPreExecution(UseCreditsArgs calldata _args) internal {
        // Check that the external call has been allowed.
        if (!allowedCustomExternalCalls[_args.externalCall.target][_args.externalCall.selector]) {
            revert CustomExternalCallNotAllowed(_args.externalCall.target, _args.externalCall.selector);
        }

        // Check that the external call has not expired.
        if (block.timestamp > _args.externalCall.expiresAt) {
            revert CustomExternalCallExpired(_args.externalCall.expiresAt);
        }

        bytes32 hashedCustomExternalCallSignature = keccak256(_args.customExternalCallSignature);

        // Check that the external call has not been used yet.
        if (usedCustomExternalCallSignature[hashedCustomExternalCallSignature]) {
            revert UsedCustomExternalCallSignature(hashedCustomExternalCallSignature);
        }

        // Mark the external call as used.
        usedCustomExternalCallSignature[hashedCustomExternalCallSignature] = true;

        // Recover the signer of the external call.
        address recoveredSigner =
            keccak256(abi.encode(_msgSender(), block.chainid, address(this), _args.externalCall)).recover(_args.customExternalCallSignature);

        // Check that the signer of the external call has the external call signer role.
        if (!hasRole(EXTERNAL_CALL_SIGNER_ROLE, recoveredSigner)) {
            revert InvalidCustomExternalCallSignature(recoveredSigner);
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // ------------------------------ EXECUTION FUNCTIONS --------------------------------------------------------------
    // -----------------------------------------------------------------------------------------------------------------

    /// @dev Executes the external call.
    /// @param _args The arguments for the useCredits function.
    /// @param _sender The caller of the useCredits function.
    /// @return manaTransferred The amount of MANA transferred out of the contract after the external call.
    function _executeExternalCall(UseCreditsArgs calldata _args, address _sender) internal returns (uint256 manaTransferred) {
        // Transfer the mana the caller is willing to pay from their wallet to this contract.
        // The caller will be returned any exceeding amount that was not needed to cover the uncredited amount.
        mana.safeTransferFrom(_sender, address(this), _args.maxUncreditedValue);

        // Approves the combined amount of credited and uncredited mana the caller is willing to pay.
        mana.forceApprove(_args.externalCall.target, _args.maxUncreditedValue + _args.maxCreditedValue);

        // Store the mana balance before the external call.
        uint256 balanceBefore = mana.balanceOf(address(this));

        // Execute the external call.
        (bool success,) = _args.externalCall.target.call(abi.encodePacked(_args.externalCall.selector, _args.externalCall.data));

        if (!success) {
            revert ExternalCallFailed(_args.externalCall);
        }

        // Store how much MANA was transferred out of the contract after the external call.
        manaTransferred = balanceBefore - mana.balanceOf(address(this));

        // Check that at least some mana was transferred out of the contract.
        if (manaTransferred == 0) {
            revert NoMANATransfer();
        }

        // Reset the approval back to 0 in case less than the approved was transferred out.
        mana.forceApprove(_args.externalCall.target, 0);
    }

    // -----------------------------------------------------------------------------------------------------------------
    // ------------------------------ POST EXECUTION FUNCTIONS ---------------------------------------------------------
    // -----------------------------------------------------------------------------------------------------------------

    /// @dev Handles the logic that needs to be done after the external call has been executed.
    /// @param _args The arguments for the useCredits function.
    /// @param _sender The caller of the useCredits function.
    function _handlePostExecution(UseCreditsArgs calldata _args, address _sender) internal {
        if (_args.externalCall.target == legacyMarketplace) {
            _handleLegacyMarketplacePostExecution(_args, _sender);
        }
    }

    /// @dev Handles the logic that needs to be done after the external call has been executed for the Legacy Marketplace.
    /// @param _args The arguments for the useCredits function.
    /// @param _sender The caller of the useCredits function.
    function _handleLegacyMarketplacePostExecution(UseCreditsArgs calldata _args, address _sender) internal {
        (address contractAddress, uint256 tokenId) = abi.decode(_args.externalCall.data, (address, uint256));

        // When an order is executed, the asset is transferred to the caller, which in this case is this contract.
        // We need to transfer the asset back to the user that is using the credits.
        IERC721(contractAddress).safeTransferFrom(address(this), _sender, tokenId);
    }

    // -----------------------------------------------------------------------------------------------------------------
    // ------------------------------ CREDIT FUNCTIONS -----------------------------------------------------------------
    // -----------------------------------------------------------------------------------------------------------------

    /// @dev Validates and applies the credits.
    /// @param _args The arguments for the useCredits function.
    /// @param _sender The caller of the useCredits function.
    /// @param _manaTransferred The amount of MANA transferred out of the contract after the external call.
    /// @return creditedValue The amount of MANA credited from the credits.
    function _validateAndApplyCredits(UseCreditsArgs calldata _args, address _sender, uint256 _manaTransferred)
        internal
        returns (uint256 creditedValue)
    {
        // Check that the number of credits is not 0.
        if (_args.credits.length == 0) {
            revert NoCredits();
        }

        // Check that the number of credits and the number of signatures are the same.
        if (_args.credits.length != _args.creditsSignatures.length) {
            revert InvalidCreditsSignaturesLength();
        }

        // Check that the maximum amount of MANA that can be credited is not 0.
        if (_args.maxCreditedValue == 0) {
            revert MaxCreditedValueZero();
        }

        // Iterate over all the provided credits to determine how much will be consumed and credited to the user
        // depending on the mana that was transferred out.
        for (uint256 i = 0; i < _args.credits.length; i++) {
            Credit calldata credit = _args.credits[i];

            if (credit.value == 0) {
                revert InvalidCreditValue();
            }

            bytes32 signatureHash = keccak256(_args.creditsSignatures[i]);

            // Check that the credit has not expired.
            if (block.timestamp > credit.expiresAt) {
                revert CreditExpired(signatureHash);
            }

            // Check that the credit has not been revoked.
            if (isRevoked[signatureHash]) {
                revert RevokedCredit(signatureHash);
            }

            // Recover the signer of the signature.
            address recoveredSigner = keccak256(abi.encode(_sender, block.chainid, address(this), credit)).recover(_args.creditsSignatures[i]);

            // Check that the signature has been signed by the signer role.
            if (!hasRole(SIGNER_ROLE, recoveredSigner)) {
                revert InvalidSignature(signatureHash, recoveredSigner);
            }

            // Calculate how much of the credit is left to be spent.
            uint256 creditRemainingValue = credit.value - spentValue[signatureHash];

            // Check that the credit has not been completely consumed.
            if (creditRemainingValue == 0) {
                revert CreditConsumed(signatureHash);
            }

            // Calculate how much MANA is left to be credited from the total MANA transferred in the external call.
            uint256 uncreditedValue = _manaTransferred - creditedValue;

            // Calculate how much of the credit to spend.
            // If the required amount is lower than the available amount, spend the required amount and leave some credit amount for future calls.
            uint256 creditValueToSpend = uncreditedValue < creditRemainingValue ? uncreditedValue : creditRemainingValue;

            // Increment the amount consumed from the credit.
            spentValue[signatureHash] += creditValueToSpend;

            // Add the credited amount to the total credited amount.
            creditedValue += creditValueToSpend;

            emit CreditUsed(signatureHash, credit, creditValueToSpend);

            // If enough credits have been spent, exit early to avoid unnecessary iterations.
            if (creditedValue == _manaTransferred) {
                break;
            }
        }

        emit CreditsUsed(_manaTransferred, creditedValue);
    }

    /// @dev Validates the amount of MANA credited.
    /// @param _args The arguments for the useCredits function.
    /// @param _creditedValue The amount of MANA credited.
    function _validateCreditedValue(UseCreditsArgs calldata _args, uint256 _creditedValue) internal {
        // Checks that the amount of MANA credited is not higher than the maximum amount allowed.
        if (_creditedValue > _args.maxCreditedValue) {
            revert MaxCreditedValueExceeded(_creditedValue, _args.maxCreditedValue);
        }

        uint256 currentHour = block.timestamp / 1 hours;
        uint256 creditableManaThisHour;

        // Calculates how much mana could be credited this hour.
        if (currentHour != hourOfLastManaCredit) {
            // If the current hour is different than the one of the last execution, resets the values.
            manaCreditedThisHour = 0;
            hourOfLastManaCredit = currentHour;

            // This new hour allows the maximum amount to be credited.
            creditableManaThisHour = maxManaCreditedPerHour;
        } else {
            // If it is the same hour, the max creditable amount has to consider the amount already credited.
            creditableManaThisHour = maxManaCreditedPerHour - manaCreditedThisHour;
        }

        // If the credited amount in this transaction is higher than the allowed this hour, it reverts.
        if (_creditedValue > creditableManaThisHour) {
            revert MaxManaCreditedPerHourExceeded(creditableManaThisHour, _creditedValue);
        }

        // Increase the amount of mana credited this hour.
        manaCreditedThisHour += _creditedValue;
    }

    /// @dev Handles the uncredited value.
    /// @param _args The arguments for the useCredits function.
    /// @param _uncreditedValue The amount of MANA that was not covered by credits.
    /// @param _sender The caller of the useCredits function.
    function _handleUncreditedValue(UseCreditsArgs calldata _args, uint256 _uncreditedValue, address _sender) internal {
        // Check that the amount that was not covered by credits is not higher than the maximum allowed by the caller.
        if (_uncreditedValue > _args.maxUncreditedValue) {
            revert MaxUncreditedValueExceeded(_uncreditedValue, _args.maxUncreditedValue);
        }

        // If the uncredited amount is less than the maximum allowed by the caller, transfer the difference back to the caller.
        if (_uncreditedValue < _args.maxUncreditedValue) {
            mana.safeTransfer(_sender, _args.maxUncreditedValue - _uncreditedValue);
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // ------------------------------ OTHER INTERNAL FUNCTIONS ---------------------------------------------------------
    // -----------------------------------------------------------------------------------------------------------------

    /// @dev This is to update the maximum amount of MANA that can be credited per hour.
    function _updateMaxManaCreditedPerHour(uint256 _maxManaCreditedPerHour) internal {
        maxManaCreditedPerHour = _maxManaCreditedPerHour;

        emit MaxManaCreditedPerHourUpdated(_maxManaCreditedPerHour);
    }

    /// @dev Updates whether primary sales are allowed.
    /// @param _primarySalesAllowed Whether primary sales are allowed.
    function _updatePrimarySalesAllowed(bool _primarySalesAllowed) internal {
        primarySalesAllowed = _primarySalesAllowed;

        emit PrimarySalesAllowedUpdated(_primarySalesAllowed);
    }

    /// @dev Updates whether secondary sales are allowed.
    /// @param _secondarySalesAllowed Whether secondary sales are allowed.
    function _updateSecondarySalesAllowed(bool _secondarySalesAllowed) internal {
        secondarySalesAllowed = _secondarySalesAllowed;

        emit SecondarySalesAllowedUpdated(_secondarySalesAllowed);
    }

    /// @dev This is used to prevent users from consuming credits on non-decentraland collections.
    function _verifyDecentralandCollection(address _contractAddress) internal view {
        if (!collectionFactory.isCollectionFromFactory(_contractAddress) && !collectionFactoryV3.isCollectionFromFactory(_contractAddress)) {
            revert NotDecentralandCollection(_contractAddress);
        }
    }

    /// @dev This is to support meta-transactions.
    function _msgSender() internal view override returns (address) {
        return _getMsgSender();
    }
}
