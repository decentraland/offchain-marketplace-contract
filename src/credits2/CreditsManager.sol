// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

abstract contract CreditsManager is AccessControl, Pausable, ReentrancyGuard {
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

    /// @notice Whether an external call is allowed to be made.
    /// @dev Contract address => selector => isAllowed
    mapping(address => mapping(bytes4 => bool)) public isAllowedCall;

    /// @param owner The owner of the contract.
    /// @param signer The address that can sign credits.
    /// @param pauser The address that can pause the contract.
    /// @param denier The address that can deny users from using credits.
    /// @param revoker The address that can revoke credits.
    /// @param mana The address of the MANA token.
    /// @param maxManaTransferPerHour The maximum amount of MANA that can be transferred out of the contract per hour.
    /// @param allowedTargets The targets of the external calls that are allowed.
    /// @param allowedSelectors The selectors of the targets that are allowed.
    struct Init {
        address owner;
        address signer;
        address pauser;
        address denier;
        address revoker;
        IERC20 mana;
        uint256 maxManaTransferPerHour;
        address[] allowedTargets;
        bytes4[] allowedSelectors;
    }

    /// @param _value How much ERC20 the credit is worth.
    /// @param _expiresAt The timestamp when the credit expires.
    struct Credit {
        uint256 value;
        uint256 expiresAt;
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

    constructor(Init memory _init) {
        _grantRole(DEFAULT_ADMIN_ROLE, _init.owner);

        _grantRole(SIGNER_ROLE, _init.signer);

        _grantRole(PAUSER_ROLE, _init.pauser);
        _grantRole(PAUSER_ROLE, _init.owner);

        _grantRole(DENIER_ROLE, _init.denier);
        _grantRole(DENIER_ROLE, _init.owner);

        _grantRole(REVOKER_ROLE, _init.revoker);
        _grantRole(REVOKER_ROLE, _init.owner);

        mana = _init.mana;

        _updateMaxManaTransferPerHour(_init.maxManaTransferPerHour);

        if (_init.allowedTargets.length != _init.allowedSelectors.length) {
            revert InvalidAllowedTargetsAndSelectorsLength();
        }

        for (uint256 i = 0; i < _init.allowedTargets.length; i++) {
            _allowCall(_init.allowedTargets[i], _init.allowedSelectors[i], true);
        }
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

    /// @notice Allows or disallows an external call.
    /// @param _target The contract address of the external call.
    /// @param _selector The selector of the external call.
    /// @param _value Whether the call is allowed.
    function allowCall(address _target, bytes4 _selector, bool _value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _allowCall(_target, _selector, _value);
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
    /// @param _signatures The signatures of the credits.
    /// @param _externalCall The external call to make.
    function useCredits(Credit[] calldata _credits, bytes[] calldata _signatures, ExternalCall calldata _externalCall) external nonReentrant whenNotPaused {
        if (!isAllowedCall[_externalCall.target][_externalCall.selector]) {
            revert CallNotAllowed(_externalCall.target, _externalCall.selector);
        }

        address sender = _msgSender();

        // Check if the user is denied from using credits.
        if (isDenied[sender]) {
            revert DeniedUser(sender);
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

        // Perform the external call, which is handled by the inheriting contract.
        _executeExternalCall(_externalCall);

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

            bytes calldata signature = _signatures[i];

            bytes32 signatureHash = keccak256(signature);

            // Check that the credit has not expired.
            if (block.timestamp > credit.expiresAt) {
                revert CreditExpired(signatureHash);
            }

            // Check that the credit has not been revoked.
            if (isRevoked[signatureHash]) {
                revert RevokedCredit(signatureHash);
            }

            address recoveredSigner = keccak256(abi.encode(sender, block.chainid, self, credit)).recover(signature);

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
            mana.safeTransferFrom(sender, self, manaTransferred - creditedValue);
        }

        emit CreditsUsed(manaTransferred, creditedValue);
    }

    /// @dev Must be implemented by inheriting contracts
    function _executeExternalCall(ExternalCall calldata _externalCall) internal virtual;

    function _updateMaxManaTransferPerHour(uint256 _maxManaTransferPerHour) internal {
        maxManaTransferPerHour = _maxManaTransferPerHour;

        emit MaxManaTransferPerHourUpdated(_maxManaTransferPerHour);
    }

    function _allowCall(address _target, bytes4 _selector, bool _value) internal {
        isAllowedCall[_target][_selector] = _value;

        emit CallAllowed(_target, _selector, _value);
    }
}
