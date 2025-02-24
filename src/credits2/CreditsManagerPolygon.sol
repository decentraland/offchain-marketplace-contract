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
import {IMarketplace, Trade} from "./interfaces/IMarketplace.sol";
import {ILegacyMarketplace} from "./interfaces/ILegacyMarketplace.sol";
import {ICollectionFactory} from "./interfaces/ICollectionFactory.sol";

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
    struct ExternalCall {
        address target;
        bytes4 selector;
        bytes data;
    }

    event UserDenied(address indexed _user);
    event UserAllowed(address indexed _user);
    event CreditRevoked(bytes32 indexed _creditId);
    event CreditUsed(bytes32 indexed _creditId, Credit _credit, uint256 _value);
    event CreditsUsed(uint256 _manaTransferred, uint256 _creditedValue);
    event MaxManaTransferPerHourUpdated(uint256 _maxManaTransferPerHour);
    event CallAllowed(address indexed _target, bytes4 _selector, bool _value);
    event ERC20Withdrawn(address indexed _token, uint256 _amount, address indexed _to);
    event ERC721Withdrawn(address indexed _token, uint256 _tokenId, address indexed _to);

    error CreditExpired(bytes32 _creditId);
    error DeniedUser(address _user);
    error RevokedCredit(bytes32 _creditId);
    error InvalidSignature(bytes32 _creditId, address _recoveredSigner);
    error SpentCredit(bytes32 _creditId);
    error NoMANATransfer();
    error MaxMANATransferExceeded();
    error InvalidAllowedTargetsAndSelectorsLength();
    error CallNotAllowed(address _target, bytes4 _selector);
    error NoCredits();
    error InvalidCreditValue();
    error InvalidExternalCallTarget(address _target);
    error InvalidExternalCallSelector(address _target, bytes4 _selector);
    error NotDecentralandCollection(address _contractAddress);
    error OnlyOneTradeAllowed();
    error InvalidBeneficiary();
    error InvalidTrade(Trade _trade);
    error ExternalCallFailed(ExternalCall _externalCall);

    /// @param _owner The address that acts as default admin.
    /// @param _signer The address that can sign credits.
    /// @param _pauser The address that can pause the contract.
    /// @param _denier The address that can deny users from using credits.
    /// @param _revoker The address that can revoke credits.
    /// @param _mana The MANA token.
    /// @param _maxManaTransferPerHour The maximum amount of MANA that can be transferred out of the contract per hour.
    /// @param _marketplace The Marketplace contract.
    /// @param _legacyMarketplace The Legacy Marketplace contract.
    /// @param _collectionStore The CollectionStore contract.
    /// @param _collectionFactory The CollectionFactory contract.
    /// @param _collectionFactoryV3 The CollectionFactoryV3 contract.
    constructor(
        address _owner,
        address _signer,
        address _pauser,
        address _denier,
        address _revoker,
        IERC20 _mana,
        uint256 _maxManaTransferPerHour,
        address _marketplace,
        address _legacyMarketplace,
        address _collectionStore,
        ICollectionFactory _collectionFactory,
        ICollectionFactory _collectionFactoryV3
    ) EIP712("Decentraland Credits", "1.0.0") {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        _grantRole(SIGNER_ROLE, _signer);

        _grantRole(PAUSER_ROLE, _pauser);
        _grantRole(PAUSER_ROLE, _owner);

        _grantRole(DENIER_ROLE, _denier);
        _grantRole(DENIER_ROLE, _owner);

        _grantRole(REVOKER_ROLE, _revoker);
        _grantRole(REVOKER_ROLE, _owner);

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

    function withdrawERC20(address _token, uint256 _amount, address _to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(_token).safeTransfer(_to, _amount);

        emit ERC20Withdrawn(_token, _amount, _to);
    }

    function withdrawERC721(address _token, uint256 _tokenId, address _to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC721(_token).safeTransferFrom(address(this), _to, _tokenId);

        emit ERC721Withdrawn(_token, _tokenId, _to);
    }

    /// @notice Use credits to pay for external calls that transfer MANA.
    /// @notice Credits will be spent until the MANA transferred is equal to the credited value.
    /// @notice Any unused credit value can be used on a future call.
    /// @dev The signatures must have been signed by the signer role.
    /// @param _credits The credits to use.
    /// @param _creditsSignatures The signatures of the credits.
    /// @param _externalCall The external call to make.
    function useCredits(Credit[] calldata _credits, bytes[] calldata _creditsSignatures, ExternalCall calldata _externalCall)
        external
        nonReentrant
        whenNotPaused
    {
        // Why use this contract if you don't provide any credits?
        if (_credits.length == 0) {
            revert NoCredits();
        }

        address self = address(this);

        uint256 balanceBefore = mana.balanceOf(self);

        uint256 currentHour = block.timestamp / 1 hours;

        if (currentHour != hourOfLastManaTransfer) {
            // Resets the values for the new hour.
            manaTransferredThisHour = 0;
            hourOfLastManaTransfer = currentHour;

            // If the hour is different, approve the maximum amount of MANA that can be transferred out of the contract per hour.
            mana.forceApprove(_externalCall.target, maxManaTransferPerHour);
        } else {
            // If the hour is the same, approve the remaining amount of MANA that can be transferred out of the contract.
            mana.forceApprove(_externalCall.target, maxManaTransferPerHour - manaTransferredThisHour);
        }

        address creditsConsumer = _msgSender();

        {
            if (_externalCall.target == legacyMarketplace) {
                if (_externalCall.selector != ILegacyMarketplace.executeOrder.selector) {
                    revert InvalidExternalCallSelector(_externalCall.target, _externalCall.selector);
                }

                (address contractAddress) = abi.decode(_externalCall.data, (address));

                _verifyDecentralandCollection(contractAddress);
            } else if (_externalCall.target == marketplace) {
                if (_externalCall.selector != IMarketplace.accept.selector && _externalCall.selector != IMarketplace.acceptWithCoupon.selector) {
                    revert InvalidExternalCallSelector(_externalCall.target, _externalCall.selector);
                }

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

                    tempBidCreditsSignaturesHash = keccak256(abi.encode(_creditsSignatures));
                } else {
                    revert InvalidTrade(trade);
                }
            } else if (_externalCall.target != collectionStore) {
                revert InvalidExternalCallTarget(_externalCall.target);
            }

            // Check if the user is denied from using credits.
            if (isDenied[creditsConsumer]) {
                revert DeniedUser(creditsConsumer);
            }

            // Execute the external call.
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

            if (_externalCall.target == marketplace && tempBidCreditsSignaturesHash != bytes32(0)) {
                // To recover some gas after the bid has been executed, we reset the value back to default.
                delete tempBidCreditsSignaturesHash;
            }
        }

        uint256 manaTransferred = mana.balanceOf(self) - balanceBefore;

        // Check that mana was transferred out of the contract.
        if (manaTransferred == 0) {
            revert NoMANATransfer();
        }

        // Reset the approval to 0.
        mana.forceApprove(_externalCall.target, 0);

        // Update the amount of MANA transferred this hour.
        manaTransferredThisHour += manaTransferred;

        // Track how much has been credited to cover the MANA transferred.
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

            uint256 creditRemainingValue = credit.value - spentValue[signatureHash];

            // Check that the credit has not been completely spent.
            if (creditRemainingValue == 0) {
                revert SpentCredit(signatureHash);
            }

            // Calculate how much MANA is left to be credited.
            uint256 uncreditedValue = manaTransferred - creditedValue;

            // Determine how much of the credit to spend.
            // If the value of the credit is higher than the required amount, only spend the required amount and leave the rest for future calls.
            uint256 creditValueToSpend = uncreditedValue < creditRemainingValue ? uncreditedValue : creditRemainingValue;

            spentValue[signatureHash] += creditValueToSpend;

            creditedValue += creditValueToSpend;

            emit CreditUsed(signatureHash, credit, creditValueToSpend);

            // If enough credits have been spent, break out of the loop so it doesn't iterate over the remaining credits.
            if (creditedValue == manaTransferred) {
                break;
            }
        }

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
}
