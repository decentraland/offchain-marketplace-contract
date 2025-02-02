// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";
import {NativeMetaTransaction} from "src/common/NativeMetaTransaction.sol";
import {EIP712} from "src/common/EIP712.sol";

/// @notice Enables users to use off-chain signed credits for marketplace trades.
abstract contract CreditManagerBase is Pausable, AccessControl, NativeMetaTransaction, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /// @notice The role that can sign credits.
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    /// @notice The role that can pause the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice The role that can deny users from using credits.
    bytes32 public constant DENIER_ROLE = keccak256("DENIER_ROLE");

    /// @notice The initialization parameters for the contract.
    struct BaseConstructorParams {
        address owner;
        address signer;
        address pauser;
        address denier;
        IERC20 mana;
        ICollectionFactory[] factories;
        bool primarySalesAllowed;
        bool secondarySalesAllowed;
        uint256 maxManaTransferPerHour;
    }

    /// @notice The schema of the Credit type.
    struct Credit {
        uint256 amount; // The amount of MANA that the credit is worth.
        uint256 expiration; // The expiration timestamp of the credit.
        bytes32 salt; // The salt used to generate a unique credit signature.
        bytes signature; // The signature of the credit.
    }

    /// @notice The MANA token contract.
    IERC20 public immutable mana;

    /// @notice The collection factories used to check that a contract address is a Decentraland Item/NFT.
    ICollectionFactory[] public factories;

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

    event FactoriesUpdated(address _sender, ICollectionFactory[] _factories);
    event AllowedSalesUpdated(address _sender, bool _primary, bool _secondary);
    event MaxManaTransferPerHourUpdated(address _sender, uint256 _maxManaTransferPerHour);
    event DenyListUpdated(address _sender, address _user, bool _value);

    constructor(BaseConstructorParams memory _init) EIP712("CreditManager", "1.0.0") {
        _grantRole(DEFAULT_ADMIN_ROLE, _init.owner);
        _grantRole(SIGNER_ROLE, _init.signer);
        _grantRole(PAUSER_ROLE, _init.pauser);
        _grantRole(DENIER_ROLE, _init.denier);
        _grantRole(DENIER_ROLE, _init.owner);

        mana = _init.mana;

        _updateFactories(_init.factories);
        _updateAllowedSales(_init.primarySalesAllowed, _init.secondarySalesAllowed);
        _updateMaxManaTransferPerHour(_init.maxManaTransferPerHour);
    }

    /// @notice Allows the owner to update the collection factories.
    function updateFactories(ICollectionFactory[] calldata _factories) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateFactories(_factories);
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
    function withdraw(IERC20 _token, uint256 _amount, address _beneficiary) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _token.safeTransfer(_beneficiary, _amount);
    }

    /// @dev Updates the collection factories and emits an event.
    function _updateFactories(ICollectionFactory[] memory _factories) internal {
        factories = _factories;

        emit FactoriesUpdated(_msgSender(), _factories);
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

    /// @dev Validates that the MANA transferred does not exceed the limit per hour.
    function _validateManaTransferLimit(uint256 _manaTransferred) internal {
        uint256 currentHour = block.timestamp / 1 hours;

        if (currentHour != hourOfLastManaTransfer) {
            manaTransferredThisHour = 0;
            hourOfLastManaTransfer = currentHour;
        }

        if (manaTransferredThisHour + _manaTransferred > maxManaTransferPerHour) {
            revert("Max MANA transfer per hour exceeded");
        }

        manaTransferredThisHour += _manaTransferred;
    }

    /// @dev Consumes the credits according to the amount of MANA to be transferred by the underlying operation and transfers the credited MANA to the user.
    function _consumeCredits(Credit[] calldata _credits, uint256 _manaToTransfer) internal {
        if (_credits.length == 0) {
            revert("Invalid credits length");
        }

        uint256 totalManaToCredit;

        for (uint256 i = 0; i < _credits.length; i++) {
            Credit calldata credit = _credits[i];

            if (credit.amount == 0) {
                revert("Invalid credit amount");
            }

            if (block.timestamp > credit.expiration) {
                revert("Credit has expired");
            }

            if (
                !hasRole(
                    SIGNER_ROLE,
                    keccak256(abi.encode(_msgSender(), credit.amount, credit.expiration, credit.salt, address(this), block.chainid)).recover(
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
        }

        mana.safeTransfer(_msgSender(), totalManaToCredit);
    }

    /// @dev Validates that a contract address is a Decentraland Item/NFT.
    function _validateIsDecentralandItem(address _contractAddress) internal view {
        for (uint256 i = 0; i < factories.length; i++) {
            if (factories[i].isCollectionFromFactory(_contractAddress)) {
                return;
            }
        }

        revert("Contract is not a Decentraland Item/NFT");
    }

    /// @dev Validates that primary sales are allowed.
    function _validatePrimarySalesAllowed() internal view {
        if (!primarySalesAllowed) {
            revert("Primary sales are not allowed");
        }
    }

    /// @dev Validates that secondary sales are allowed.
    function _validateSecondarySalesAllowed() internal view {
        if (!secondarySalesAllowed) {
            revert("Secondary sales are not allowed");
        }
    }

    /// @dev Overrides the _msgSender function to support Meta Transactions.
    function _msgSender() internal view override returns (address) {
        return _getMsgSender();
    }
}
