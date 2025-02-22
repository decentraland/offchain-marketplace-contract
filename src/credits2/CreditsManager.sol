// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract CreditsManager is AccessControl, Pausable {
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

    event UserDenied(address indexed user);
    event UserAllowed(address indexed user);
    event CreditRevoked(bytes32 indexed credit);

    /// @param _owner The owner of the contract.
    /// @param _signer The address that can sign credits.
    /// @param _pauser The address that can pause the contract.
    /// @param _denier The address that can deny users from using credits.
    /// @param _revoker The address that can revoke credits.
    constructor(address _owner, address _signer, address _pauser, address _denier, address _revoker) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        _grantRole(SIGNER_ROLE, _signer);

        _grantRole(PAUSER_ROLE, _pauser);
        _grantRole(PAUSER_ROLE, _owner);

        _grantRole(DENIER_ROLE, _denier);
        _grantRole(DENIER_ROLE, _owner);

        _grantRole(REVOKER_ROLE, _revoker);
        _grantRole(REVOKER_ROLE, _owner);
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
}
