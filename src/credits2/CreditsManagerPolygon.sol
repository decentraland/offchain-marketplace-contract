// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {NativeMetaTransaction, EIP712} from "../common/NativeMetaTransaction.sol";
import {IMarketplace, Trade, ExternalCheck} from "./interfaces/IMarketplace.sol";
import {ILegacyMarketplace} from "./interfaces/ILegacyMarketplace.sol";
import {ICollectionFactory} from "./interfaces/ICollectionFactory.sol";
import {ICollectionStore, ItemToBuy} from "./interfaces/ICollectionStore.sol";

contract CreditsManager is AccessControl, Pausable, ReentrancyGuard, NativeMetaTransaction {
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

    /// @notice Whether a user is denied from using credits.
    mapping(address => bool) public isDenied;

    /// @notice Whether a credit has been revoked.
    /// @dev The key is the hash of the credit signature.
    mapping(bytes32 => bool) public isRevoked;

    /// @notice The address of the MANA token.
    IERC20 public immutable mana;

    /// @notice The amount of MANA value used on each credit.
    /// @dev The key is the hash of the credit signature.
    mapping(bytes32 => uint256) spentValue;

    /// @notice Maximum amount of MANA that can be transferred out of the contract per hour.
    uint256 public maxManaTransferPerHour;

    /// @notice How much MANA has been transferred out of the contract this hour.
    uint256 public manaTransferredThisHour;

    /// @notice The hour of the last MANA transfer.
    uint256 public hourOfLastManaTransfer;

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

    /// @notice Tracks the allowed custom external calls.
    mapping(address => mapping(bytes4 => bool)) public allowedCustomExternalCalls;

    /// @notice Tracks the used external call signatures.
    mapping(bytes32 => bool) public usedCustomExternalCallSignature;

    /// @notice The roles to initialize the contract with.
    /// @dev Mainly used to decrease the number of arguments in the constructor.
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

    /// @param _value How much ERC20 the credit is worth.
    /// @param _expiresAt The timestamp when the credit expires.
    /// @param _salt Value used to generate unique credits.
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
    event CreditUsed(bytes32 indexed _creditId, Credit _credit, uint256 _value);
    event CreditsUsed(uint256 _manaTransferred, uint256 _creditedValue);
    event MaxManaTransferPerHourUpdated(uint256 _maxManaTransferPerHour);
    event ERC20Withdrawn(address indexed _token, uint256 _amount, address indexed _to);
    event ERC721Withdrawn(address indexed _token, uint256 _tokenId, address indexed _to);
    event CustomExternalCallAllowed(address indexed _target, bytes4 indexed _selector, bool _allowed);
    event CustomExternalCallRevoked(bytes32 indexed _hashedExternalCallSignature);

    error CreditExpired(bytes32 _creditId);
    error DeniedUser(address _user);
    error RevokedCredit(bytes32 _creditId);
    error InvalidSignature(bytes32 _creditId, address _recoveredSigner);
    error SpentCredit(bytes32 _creditId);
    error NoMANATransfer();
    error NoCredits();
    error InvalidCreditValue();
    error InvalidExternalCallSelector(address _target, bytes4 _selector);
    error NotDecentralandCollection(address _contractAddress);
    error OnlyOneTradeAllowed();
    error InvalidBeneficiary();
    error InvalidTrade(Trade _trade);
    error ExternalCallFailed(ExternalCall _externalCall);
    error ExternalCheckNotFound();
    error InvalidAssetsLength();
    error CustomExternalCallNotAllowed(address _target, bytes4 _selector);
    error InvalidCustomExternalCallSignature(address _recoveredSigner);
    error UsedCustomExternalCallSignature(bytes32 _hashedCustomExternalCallSignature);
    error CustomExternalCallExpired(uint256 _expiresAt);

    /// @param _roles The roles to initialize the contract with.
    /// @param _mana The MANA token.
    /// @param _maxManaTransferPerHour The maximum amount of MANA that can be transferred out of the contract per hour.
    /// @param _marketplace The Marketplace contract.
    /// @param _legacyMarketplace The Legacy Marketplace contract.
    /// @param _collectionStore The CollectionStore contract.
    /// @param _collectionFactory The CollectionFactory contract.
    /// @param _collectionFactoryV3 The CollectionFactoryV3 contract.
    constructor(
        Roles memory _roles,
        IERC20 _mana,
        uint256 _maxManaTransferPerHour,
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

        mana = _mana;

        _updateMaxManaTransferPerHour(_maxManaTransferPerHour);

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

    /// @notice Update the maximum amount of MANA that can be transferred out of the contract per hour.
    /// @param _maxManaTransferPerHour The new maximum amount of MANA that can be transferred out of the contract per hour.
    function updateMaxManaTransferPerHour(uint256 _maxManaTransferPerHour) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateMaxManaTransferPerHour(_maxManaTransferPerHour);
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
    /// @notice Credits will be spent until the MANA transferred is equal to the credited value.
    /// @notice Any unused credit value can be used on a future call.
    /// @dev The signatures must have been signed by the signer role.
    /// @param _credits The credits to use.
    /// @param _creditsSignatures The signatures of the credits.
    /// @param _externalCall The external call to make.
    /// @param _customExternalCallSignature The signature of the external call.
    /// Only used when the target is an unknown contract.
    function useCredits(
        Credit[] calldata _credits,
        bytes[] calldata _creditsSignatures,
        ExternalCall calldata _externalCall,
        bytes calldata _customExternalCallSignature
    ) external nonReentrant whenNotPaused {
        // Why use this contract if you don't provide any credits?
        if (_credits.length == 0) {
            revert NoCredits();
        }

        uint256 currentHour = block.timestamp / 1 hours;

        // Checks how much can be transferred out of the contract in the current hour.
        if (currentHour != hourOfLastManaTransfer) {
            // Resets the values as it is a new hour.
            manaTransferredThisHour = 0;
            hourOfLastManaTransfer = currentHour;

            // Approve for the maximum amount as it is a new hour.
            mana.forceApprove(_externalCall.target, maxManaTransferPerHour);
        } else {
            // Given that a transfer happened in this same hour, the approval has to be for the remaining transferable amount.
            mana.forceApprove(_externalCall.target, maxManaTransferPerHour - manaTransferredThisHour);
        }

        address self = address(this);

        // By default the consumer of the credits is the caller of the function.
        // There is a special case for bids in which the consumer is the signer of the bid instead.
        address creditsConsumer = _msgSender();

        {
            // Legacy Marketplace.
            if (_externalCall.target == legacyMarketplace) {
                // Check that only executeOrder is being called.
                // `safeExecuteOrder` is not used on Polygon given that the assets don't validate signatures like with Estates.
                if (_externalCall.selector != ILegacyMarketplace.executeOrder.selector) {
                    revert InvalidExternalCallSelector(_externalCall.target, _externalCall.selector);
                }

                // Decode the contract address from the data
                (address contractAddress) = abi.decode(_externalCall.data, (address));

                // Check that the sent assets are decentraland collections items or nfts.
                _verifyDecentralandCollection(contractAddress);
            }
            // Offchain Marketplace.
            else if (_externalCall.target == marketplace) {
                // Check that only accept or acceptWithCoupon are being called.
                if (_externalCall.selector != IMarketplace.accept.selector && _externalCall.selector != IMarketplace.acceptWithCoupon.selector) {
                    revert InvalidExternalCallSelector(_externalCall.target, _externalCall.selector);
                }

                // Decode the trades from the data.
                Trade[] memory trades = abi.decode(_externalCall.data, (Trade[]));

                // To avoid making this too complex, we only allow one trade per call.
                if (trades.length != 1) {
                    revert OnlyOneTradeAllowed();
                }

                // Given that there is only one trade, we store the one in the first index.
                Trade memory trade = trades[0];

                // Now we have to check if the trade is a valid listing or a valid bid.
                //
                // Listing:
                // - 1 mana asset received by the signer.
                // - n amount of decentraland assets sent to the caller.
                // Bid:
                // - n amount of decentraland assets received by the signer.
                // - 1 mana asset sent to the caller.
                //
                // First we verify if the trade is a listing by checking if the received assets contain only a mana asset.
                if (trade.received.length == 1 && trade.received[0].contractAddress == address(mana)) {
                    uint256 sentLength = trade.sent.length;

                    // We check that there is at least one sent asset.
                    if (sentLength == 0) {
                        revert InvalidAssetsLength();
                    }

                    for (uint256 j = 0; j < sentLength; j++) {
                        // We check that the sent assets are decentraland collections items or nfts.
                        _verifyDecentralandCollection(trade.sent[j].contractAddress);

                        // We check that the beneficiary of the decentraland assets is not 0 so they are not received by this contract.
                        if (trade.sent[j].beneficiary == address(0)) {
                            revert InvalidBeneficiary();
                        }
                    }
                }
                // If it is not a listing, we verify that it is a bid by checking if the sent assets contain only a mana asset.
                else if (trade.sent.length == 1 && trade.sent[0].contractAddress == address(mana)) {
                    uint256 receivedLength = trade.received.length;

                    // We check that there is at least one received asset.
                    if (receivedLength == 0) {
                        revert InvalidAssetsLength();
                    }

                    for (uint256 j = 0; j < receivedLength; j++) {
                        // We check that the received assets are decentraland collections items or nfts.
                        // There is no need to check that the beneficiary is not 0 because the signer (bidder) address will be used in that case.
                        _verifyDecentralandCollection(trade.received[j].contractAddress);
                    }

                    // We check that the bid has an external check with this contract to verify that the credits provided are
                    // the same as the ones the bidder wants to use.
                    bool hasExternalCheck = false;

                    for (uint256 j = 0; j < trade.checks.externalChecks.length; j++) {
                        ExternalCheck memory externalCheck = trade.checks.externalChecks[j];

                        // We check that at least one required external check has this contract as target and is calling the bidExternalCheck function.
                        if (
                            externalCheck.contractAddress == address(this) && externalCheck.selector == this.bidExternalCheck.selector
                                && externalCheck.required
                        ) {
                            hasExternalCheck = true;
                        }
                    }

                    // If we can't find the external check, we revert.
                    if (!hasExternalCheck) {
                        revert ExternalCheckNotFound();
                    }

                    // Stores the hash of the credits to be consumed on the bid so it can be verified on the external check.
                    tempBidCreditsSignaturesHash = keccak256(abi.encode(_creditsSignatures));

                    // For bids, the consumer of the credits is the bidder, as it will be the signer of the bid the one paying with mana.
                    creditsConsumer = trade.signer;
                } else {
                    revert InvalidTrade(trade);
                }
            }
            // CollectionStore.
            else if (_externalCall.target == collectionStore) {
                // Check that only buy is being called.
                if (_externalCall.selector != ICollectionStore.buy.selector) {
                    revert InvalidExternalCallSelector(_externalCall.target, _externalCall.selector);
                }

                // Decode the items to buy from the data.
                ItemToBuy[] memory itemsToBuy = abi.decode(_externalCall.data, (ItemToBuy[]));

                // We check that there is at least one item to buy.
                if (itemsToBuy.length == 0) {
                    revert InvalidAssetsLength();
                }

                for (uint256 i = 0; i < itemsToBuy.length; i++) {
                    ItemToBuy memory itemToBuy = itemsToBuy[i];

                    // We check that the collection has been created by a CollectionFactory and has not been deployed randomly by a malicious actor.
                    _verifyDecentralandCollection(itemToBuy.collection);
                }
            } 
            // Custom external call.
            // If the target does not match with any of the coded targets, it is considered a custom external call.
            // These calls can only be performed if they have been allowed by the owner beforehand and have to be signed by a special address.
            else {
                // Check that the external call has been allowed.
                if (!allowedCustomExternalCalls[_externalCall.target][_externalCall.selector]) {
                    revert CustomExternalCallNotAllowed(_externalCall.target, _externalCall.selector);
                }

                // Check that the external call has not expired.
                if (_externalCall.expiresAt != 0 && block.timestamp > _externalCall.expiresAt) {
                    revert CustomExternalCallExpired(_externalCall.expiresAt);
                }

                bytes32 hashedCustomExternalCallSignature = keccak256(_customExternalCallSignature);

                // Check that the external call has not been used yet.
                if (usedCustomExternalCallSignature[hashedCustomExternalCallSignature]) {
                    revert UsedCustomExternalCallSignature(hashedCustomExternalCallSignature);
                }

                // Mark the external call as used.
                usedCustomExternalCallSignature[hashedCustomExternalCallSignature] = true;

                // Recover the signer of the external call.
                address recoveredSigner = keccak256(abi.encode(creditsConsumer, block.chainid, self, _externalCall)).recover(_customExternalCallSignature);

                // Check that the signer of the external call has the external call signer role.
                if (!hasRole(EXTERNAL_CALL_SIGNER_ROLE, recoveredSigner)) {
                    revert InvalidCustomExternalCallSignature(recoveredSigner);
                }
            }
        }

        // Check if the consumer has been denied from using credits.
        if (isDenied[creditsConsumer]) {
            revert DeniedUser(creditsConsumer);
        }

        // Store the mana balance before the external call.
        uint256 balanceBefore = mana.balanceOf(self);

        // Execute the external call.
        (bool success,) = _externalCall.target.call(abi.encodeWithSelector(_externalCall.selector, _externalCall.data));

        if (!success) {
            revert ExternalCallFailed(_externalCall);
        }

        // Handle post execution logic for different targets.
        //
        // Legacy Marketplace.
        if (_externalCall.target == legacyMarketplace) {
            (address contractAddress, uint256 tokenId) = abi.decode(_externalCall.data, (address, uint256));

            // When an order is executed, the asset is transferred to the caller, which in this case is this contract.
            // We need to transfer the asset back to the user that is using the credits.
            IERC721(contractAddress).safeTransferFrom(address(this), creditsConsumer, tokenId);
        }
        // Offchain Marketplace.
        else if (_externalCall.target == marketplace && tempBidCreditsSignaturesHash != bytes32(0)) {
            // To recover some gas after the bid has been executed, we reset the value back to default.
            delete tempBidCreditsSignaturesHash;
        }

        // Store how much MANA was transferred out of the contract after the external call.
        uint256 manaTransferred = mana.balanceOf(self) - balanceBefore;

        // Check that mana was transferred out of the contract.
        if (manaTransferred == 0) {
            revert NoMANATransfer();
        }

        // Reset the approval back to 0 in case the amount allowed this hour was more than required.
        mana.forceApprove(_externalCall.target, 0);

        // Increment the amount of MANA transferred this hour.
        manaTransferredThisHour += manaTransferred;

        // Keeps track of how much MANA is credited by the credits.
        uint256 creditedValue = 0;

        for (uint256 i = 0; i < _credits.length; i++) {
            Credit calldata credit = _credits[i];

            if (credit.value == 0) {
                revert InvalidCreditValue();
            }

            bytes calldata signature = _creditsSignatures[i];

            bytes32 signatureHash = keccak256(signature);

            // Check that the credit has not expired.
            if (block.timestamp > credit.expiresAt) {
                revert CreditExpired(signatureHash);
            }

            // Check that the credit has not been revoked.
            if (isRevoked[signatureHash]) {
                revert RevokedCredit(signatureHash);
            }

            address recoveredSigner = keccak256(abi.encode(creditsConsumer, block.chainid, self, credit)).recover(signature);

            // Check that the signature has been signed by the signer role.
            if (!hasRole(SIGNER_ROLE, recoveredSigner)) {
                revert InvalidSignature(signatureHash, recoveredSigner);
            }

            // Calculate how much of the credit is left to be spent.
            uint256 creditRemainingValue = credit.value - spentValue[signatureHash];

            // Check that the credit has not been completely spent.
            if (creditRemainingValue == 0) {
                revert SpentCredit(signatureHash);
            }

            // Calculate how much MANA is left to be credited from the total MANA transferred in the external call.
            uint256 uncreditedValue = manaTransferred - creditedValue;

            // Calculate how much of the credit to spend.
            // If the value of the credit is higher than the required amount, only spend the required amount and leave the rest for future calls.
            uint256 creditValueToSpend = uncreditedValue < creditRemainingValue ? uncreditedValue : creditRemainingValue;

            // Increment the amount consumed from the credit.
            spentValue[signatureHash] += creditValueToSpend;

            // Increment the amount of MANA credited.
            creditedValue += creditValueToSpend;

            emit CreditUsed(signatureHash, credit, creditValueToSpend);

            // If enough credits have been spent, break out of the loop so it doesn't iterate over the remaining credits.
            if (creditedValue == manaTransferred) {
                break;
            }
        }

        // If the credits could not amount to the total MANA transferred, the user has to pay back the difference to the contract.
        if (manaTransferred > creditedValue) {
            mana.safeTransferFrom(creditsConsumer, self, manaTransferred - creditedValue);
        }

        emit CreditsUsed(manaTransferred, creditedValue);
    }

    /// @notice Function used by the Marketplace to verify that the credits being used have been validated by the bid signer.
    /// @param _caller The address of the user that has called the Marketplace (Has to be this contract).
    /// @param _data The data of the external check (The hash of the signatures of the Credits to be used).
    function bidExternalCheck(address _caller, bytes calldata _data) external view returns (bool) {
        return _caller == address(this) && abi.decode(_data, (bytes32)) == tempBidCreditsSignaturesHash;
    }

    /// @dev This is to update the maximum amount of MANA that can be transferred out of the contract per hour.
    function _updateMaxManaTransferPerHour(uint256 _maxManaTransferPerHour) internal {
        maxManaTransferPerHour = _maxManaTransferPerHour;

        emit MaxManaTransferPerHourUpdated(_maxManaTransferPerHour);
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
