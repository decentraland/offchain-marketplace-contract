// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";

import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";
import {NativeMetaTransaction} from "src/common/NativeMetaTransaction.sol";
import {EIP712} from "src/common/EIP712.sol";

/// @notice Enables users to use off-chain signed credits for marketplace trades.
abstract contract CreditManagerBase is Pausable, AccessControl, NativeMetaTransaction, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /// @notice The role that can sign credits.
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    /// @notice The role that can pause the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice The role that can deny users from using credits.
    bytes32 public constant DENIER_ROLE = keccak256("DENIER_ROLE");

    /// @param owner The owner of the contract.
    /// @param signer The address that can sign credits.
    /// @param pauser The address that can pause the contract.
    /// @param denier The address that can deny users from using credits.
    /// @param isPolygon Whether the contract is being deployed on Polygon or Polygon Testnet, or Ethereum or Ethereum Testnet.
    /// @param collectionFactory The collection factory used to check that a contract address is a Decentraland Item/NFT.
    /// @param collectionFactoryV3 The other collection factory used to check that a contract address is a Decentraland Item/NFT.
    /// @param land The contract address of the LAND NFT used to validate that the traded NFT is a LAND.
    /// @param estate The contract address of the ESTATE NFT used to validate that the traded NFT is an ESTATE.
    /// @param nameRegistry The contract address of the NAME REGISTRY used to validate that the traded NFT is a NAME.
    /// @param mana The MANA token contract.
    /// @param primarySalesAllowed Whether using credits for primary sales is allowed.
    /// @param secondarySalesAllowed Whether using credits for secondary sales is allowed.
    /// @param maxManaTransferPerHour The maximum amount of MANA that can be transferred out of the contract per hour.
    struct CreditManagerBaseInit {
        address owner;
        address signer;
        address pauser;
        address denier;
        bool isPolygon;
        ICollectionFactory collectionFactory;
        ICollectionFactory collectionFactoryV3;
        address land;
        address estate;
        address nameRegistry;
        IERC20 mana;
        bool primarySalesAllowed;
        bool secondarySalesAllowed;
        uint256 maxManaTransferPerHour;
    }

    /// @param amount The amount of MANA that the credit is worth.
    /// @param expiration The expiration timestamp of the credit.
    /// @param salt The salt used to generate a unique credit signature.
    /// @param signature The signature of the credit.
    struct Credit {
        uint256 amount;
        uint256 expiration;
        bytes32 salt;
        bytes signature;
    }

    /// @notice Wheter the contract is being deployed on Polygon or Polygon Testnet, or Ethereum or Ethereum Testnet.
    bool public immutable isPolygon;

    /// @notice One of the collection factories used to check that a contract address is a Decentraland Item/NFT.
    /// @dev This is only used on Polygon or Polygon Testnets.
    ICollectionFactory public immutable collectionFactory;

    /// @notice The other collection factory used to check that a contract address is a Decentraland Item/NFT.
    /// @dev This is only used on Polygon or Polygon Testnets.
    ICollectionFactory public immutable collectionFactoryV3;

    /// @notice The contract address of the LAND NFT used to validate that the traded NFT is a LAND.
    /// @dev This is only used on Ethereum or Ethereum Testnet.
    address public immutable land;

    /// @notice The contract address of the ESTATE NFT used to validate that the traded NFT is an ESTATE.
    /// @dev This is only used on Ethereum or Ethereum Testnet.
    address public immutable estate;

    /// @notice The contract address of the NAME REGISTRY used to validate that the traded NFT is a NAME.
    /// @dev This is only used on Ethereum or Ethereum Testnet.
    address public immutable nameRegistry;

    /// @notice The MANA token contract.
    IERC20 public immutable mana;

    /// @notice How many credits have been spent from a particular credit.
    /// The key is the keccak256 hash of the credit signature.
    mapping(bytes32 => uint256) public spentCredits;

    /// @notice The users that have been denied from using credits.
    mapping(address => bool) public denyList;

    /// @notice Whether using credits for primary sales is allowed.
    bool public primarySalesAllowed;

    /// @notice Whether using credits for secondary sales is allowed.
    bool public secondarySalesAllowed;

    /// @notice Maximum amount of MANA that can be transferred out of the contract per hour.
    uint256 public maxManaTransferPerHour;

    /// @notice How much MANA has been transferred out of the contract this hour.
    uint256 public manaTransferredThisHour;

    /// @notice The hour of the last MANA transfer.
    uint256 public hourOfLastManaTransfer;

    event AllowedSalesUpdated(address indexed _sender, bool _primary, bool _secondary);
    event MaxManaTransferPerHourUpdated(address indexed _sender, uint256 _maxManaTransferPerHour);
    event DenyListUpdated(address indexed _sender, address indexed _user, bool _value);
    event CreditConsumed(address indexed _sender, Credit _credit);

    constructor(CreditManagerBaseInit memory _init) EIP712("CreditManager", "1.0.0") {
        _grantRole(DEFAULT_ADMIN_ROLE, _init.owner);
        _grantRole(SIGNER_ROLE, _init.signer);
        _grantRole(PAUSER_ROLE, _init.pauser);
        _grantRole(DENIER_ROLE, _init.denier);
        _grantRole(DENIER_ROLE, _init.owner);

        mana = _init.mana;
        isPolygon = _init.isPolygon;
        collectionFactory = _init.collectionFactory;
        collectionFactoryV3 = _init.collectionFactoryV3;
        land = _init.land;
        estate = _init.estate;
        nameRegistry = _init.nameRegistry;

        _updateAllowedSales(_init.primarySalesAllowed, _init.secondarySalesAllowed);
        _updateMaxManaTransferPerHour(_init.maxManaTransferPerHour);
    }

    /// @notice Allows the owner to update if primary or secondary sales are allowed.
    function updateAllowedSales(bool _primary, bool _secondary) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateAllowedSales(_primary, _secondary);
    }

    /// @notice Allows the owner to update how much MANA can be transferred out of the contract per hour.
    function updateMaxManaTransferPerHour(uint256 _maxManaTransferPerHour) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateMaxManaTransferPerHour(_maxManaTransferPerHour);
    }

    /// @notice Allows users with the denier role to add users to the deny list and prevent them from using credits.
    /// Only the owner can remove users from the deny list.
    function updateDenyList(address[] calldata _users, bool[] calldata _values) external {
        address sender = _msgSender();

        for (uint256 i = 0; i < _users.length; i++) {
            bool value = _values[i];

            if (!hasRole(value ? DENIER_ROLE : DEFAULT_ADMIN_ROLE, sender)) {
                revert("Sender is not allowed");
            }

            _updateDenyList(_users[i], value);
        }
    }

    /// @notice Allows users with the pauser role to pause the contract.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Allows the owner to unpause the contract.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Allows the owner to withdraw any ERC20 token from the contract.
    function withdrawERC20(IERC20 _token, uint256 _amount, address _beneficiary) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _token.safeTransfer(_beneficiary, _amount);
    }

    /// @notice Allows the owner to withdraw any ERC721 token from the contract.
    function withdrawERC721(IERC721 _token, uint256 _tokenId, address _beneficiary) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _token.safeTransferFrom(address(this), _beneficiary, _tokenId);
    }

    /// @notice Allows the contract to receive ERC721 tokens.
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @dev Updates if primary or secondary sales are allowed and emits an event.
    function _updateAllowedSales(bool _primary, bool _secondary) internal {
        primarySalesAllowed = _primary;
        secondarySalesAllowed = _secondary;

        emit AllowedSalesUpdated(_msgSender(), _primary, _secondary);
    }

    /// @dev Updates the maximum MANA transfer per hour and emits an event.
    function _updateMaxManaTransferPerHour(uint256 _maxManaTransferPerHour) internal {
        maxManaTransferPerHour = _maxManaTransferPerHour;

        emit MaxManaTransferPerHourUpdated(_msgSender(), _maxManaTransferPerHour);
    }

    /// @dev Updates the deny list and emits an event.
    function _updateDenyList(address _user, bool _value) internal {
        denyList[_user] = _value;

        emit DenyListUpdated(_msgSender(), _user, _value);
    }

    /// @dev Computes how much MANA has to be credited to the user according to the credits and the amount of MANA to be transferred.
    /// It will consume credit amount in the order of the credits array.
    /// If the credits contain more MANA than the amount to be transferred, the excess MANA will not be credited and will remain available for future transfers.
    function _computeTotalManaToCredit(Credit[] calldata _credits, uint256 _manaToTransfer) internal returns (uint256 totalManaToCredit) {
        _validateManaTransferLimit(_manaToTransfer);

        if (_credits.length == 0) {
            revert("No credits provided");
        }

        for (uint256 i = 0; i < _credits.length; i++) {
            Credit calldata credit = _credits[i];

            if (block.timestamp > credit.expiration) {
                revert("Credit has expired");
            }

            address sender = _msgSender();

            if (
                !hasRole(
                    SIGNER_ROLE,
                    keccak256(abi.encode(sender, address(this), block.chainid, credit.amount, credit.expiration, credit.salt)).recover(
                        credit.signature
                    )
                )
            ) {
                revert("Invalid credit signature");
            }

            bytes32 sigHash = keccak256(credit.signature);

            uint256 manaToCredit = credit.amount - spentCredits[sigHash];

            if (manaToCredit == 0) {
                revert("Credit has been spent");
            }

            uint256 diff = _manaToTransfer - totalManaToCredit;

            manaToCredit = manaToCredit > diff ? diff : manaToCredit;

            totalManaToCredit += manaToCredit;

            spentCredits[sigHash] += manaToCredit;

            emit CreditConsumed(sender, credit);
        }
    }

    /// @dev Validates that the MANA transferred does not exceed the limit per hour.
    function _validateManaTransferLimit(uint256 _manaToTransfer) private {
        uint256 currentHour = block.timestamp / 1 hours;

        if (currentHour != hourOfLastManaTransfer) {
            manaTransferredThisHour = 0;
            hourOfLastManaTransfer = currentHour;
        }

        if (manaTransferredThisHour + _manaToTransfer > maxManaTransferPerHour) {
            revert("Max MANA transfer per hour exceeded");
        }

        manaTransferredThisHour += _manaToTransfer;
    }

    /// @dev Validates that a contract address is a Decentraland Item/NFT.
    function _validateContractAddress(address _contractAddress) internal view {
        if (isPolygon) {
            if (collectionFactoryV3.isCollectionFromFactory(_contractAddress) || collectionFactory.isCollectionFromFactory(_contractAddress)) {
                return;
            }
        } else if (_contractAddress == land || _contractAddress == estate || _contractAddress == nameRegistry) {
            return;
        }

        revert("Invalid contract address");
    }

    /// @dev Validates that primary sales are allowed.
    /// This is toggled by the owner of the contract.
    function _validatePrimarySalesAllowed() internal view {
        if (!primarySalesAllowed) {
            revert("Primary sales are not allowed");
        }
    }

    /// @dev Validates that secondary sales are allowed.
    /// This is toggled by the owner of the contract.
    function _validateSecondarySalesAllowed() internal view {
        if (!secondarySalesAllowed) {
            revert("Secondary sales are not allowed");
        }
    }

    /// @dev Validates that the balance of the contract after a marketplace trade is the expected one.
    function _validateResultingBalance(uint256 _originalBalance, uint256 _expectedDiff) internal view {
        if (_originalBalance - mana.balanceOf(address(this)) != _expectedDiff) {
            revert("MANA transfer mismatch");
        }
    }

    /// @dev Calculates the difference between the MANA required for the trade and the MANA credits.
    /// Given that the contract transfers the full MANA required for the trade, it is required for the sender
    /// to transfer any uncredited MANA back to the contract.
    ///
    /// Example:
    ///   - Trade requires 100 MANA
    ///   - User has a credit worth 75 MANA
    ///   - Contract pays 100 MANA for the trade
    ///   - User must transfer 25 MANA back to cover the uncredited amount
    function _transferDiffBackToContract(uint256 _manaToCredit, uint256 _manaToTransfer) internal {
        uint256 uncreditedMana = _manaToTransfer - _manaToCredit;

        if (uncreditedMana > 0) {
            mana.safeTransferFrom(_msgSender(), address(this), uncreditedMana);
        }
    }

    /// @dev Overrides the _msgSender function to support Meta Transactions.
    function _msgSender() internal view override returns (address) {
        return _getMsgSender();
    }
}
