// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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

    /// @param _value How much ERC20 the credit is worth.
    /// @param _expiresAt The timestamp when the credit expires.
    struct Credit {
        uint256 value;
        uint256 expiresAt;
    }

    event UserDenied(address indexed _user);
    event UserAllowed(address indexed _user);
    event CreditRevoked(bytes32 indexed _creditId);
    event CreditUsed(bytes32 indexed _creditId, Credit _credit, uint256 _value);

    error CreditExpired(bytes32 _creditId);
    error DeniedUser(address _user);
    error RevokedCredit(bytes32 _creditId);
    error InvalidSignature(bytes32 _creditId, address _recoveredSigner);
    error SpentCredit(bytes32 _creditId);

    /// @param _owner The owner of the contract.
    /// @param _signer The address that can sign credits.
    /// @param _pauser The address that can pause the contract.
    /// @param _denier The address that can deny users from using credits.
    /// @param _revoker The address that can revoke credits.
    /// @param _mana The address of the MANA token.
    constructor(address _owner, address _signer, address _pauser, address _denier, address _revoker, IERC20 _mana) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        _grantRole(SIGNER_ROLE, _signer);

        _grantRole(PAUSER_ROLE, _pauser);
        _grantRole(PAUSER_ROLE, _owner);

        _grantRole(DENIER_ROLE, _denier);
        _grantRole(DENIER_ROLE, _owner);

        _grantRole(REVOKER_ROLE, _revoker);
        _grantRole(REVOKER_ROLE, _owner);

        mana = _mana;
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

    function useCredits(Credit[] calldata _credits, bytes[] calldata _signatures) external nonReentrant {
        address sender = _msgSender();

        if (isDenied[sender]) {
            revert DeniedUser(sender);
        }

        address self = address(this);

        uint256 balanceBefore = mana.balanceOf(self);

        _externalCall();

        uint256 manaTransferred = mana.balanceOf(self) - balanceBefore;

        uint256 creditedValue = 0;

        for (uint256 i = 0; i < _credits.length; i++) {
            Credit calldata credit = _credits[i];

            bytes calldata signature = _signatures[i];

            bytes32 signatureHash = keccak256(signature);

            if (block.timestamp > credit.expiresAt) {
                revert CreditExpired(signatureHash);
            }

            if (isRevoked[signatureHash]) {
                revert RevokedCredit(signatureHash);
            }

            address recoveredSigner = keccak256(abi.encode(sender, block.chainid, self, credit)).recover(signature);

            if (!hasRole(SIGNER_ROLE, recoveredSigner)) {
                revert InvalidSignature(signatureHash, recoveredSigner);
            }

            uint256 creditRemainingValue = credit.value - spentValue[signatureHash];

            if (creditRemainingValue == 0) {
                revert SpentCredit(signatureHash);
            }

            uint256 diff = manaTransferred - creditedValue;

            uint256 creditValueToSpend = diff < creditRemainingValue ? diff : creditRemainingValue;

            spentValue[signatureHash] += creditValueToSpend;

            creditedValue += creditValueToSpend;

            emit CreditUsed(signatureHash, credit, creditValueToSpend);
        }

        if (manaTransferred > creditedValue) {
            mana.safeTransferFrom(sender, self, manaTransferred - creditedValue);
        }
    }

    function _externalCall() internal virtual;
}
