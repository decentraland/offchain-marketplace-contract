// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {NativeMetaTransaction, EIP712} from "src/common/NativeMetaTransaction.sol";
import {IMarketplace} from "src/credits/interfaces/IMarketplace.sol";
import {ILegacyMarketplace} from "src/credits/interfaces/ILegacyMarketplace.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";
import {ICollectionStore} from "src/credits/interfaces/ICollectionStore.sol";

abstract contract CreditsManagerPolygonStorage {
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

    /// @notice The maximum amount of MANA the bidder is willing to pay from their wallet when credits are insufficient to cover the total transaction cost.
    uint256 public tempMaxUncreditedValue;

    /// @dev Initializes immutable variables.
    /// @param _mana The MANA token.
    /// @param _marketplace The Marketplace contract.
    /// @param _legacyMarketplace The Legacy Marketplace contract.
    /// @param _collectionStore The CollectionStore contract.
    /// @param _collectionFactory The CollectionFactory contract.
    /// @param _collectionFactoryV3 The CollectionFactoryV3 contract.
    constructor(
        IERC20 _mana,
        address _marketplace,
        address _legacyMarketplace,
        address _collectionStore,
        ICollectionFactory _collectionFactory,
        ICollectionFactory _collectionFactoryV3
    ) {
        mana = _mana;
        marketplace = _marketplace;
        legacyMarketplace = _legacyMarketplace;
        collectionStore = _collectionStore;
        collectionFactory = _collectionFactory;
        collectionFactoryV3 = _collectionFactoryV3;
    }
}
