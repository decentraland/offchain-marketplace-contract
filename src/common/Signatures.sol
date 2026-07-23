// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import {EIP712} from "src/common/EIP712.sol";

/// @dev Adds some functions to manage signatures.
abstract contract Signatures is Ownable, EIP712 {
    /// @notice Value of the current contract signature index.
    /// The owner of the contract can update this value to revoke signatures created with another value.
    uint256 public contractSignatureIndex;

    /// @notice Value of the current signer signature index.
    /// Signers can update this value to revoke signatures created with another value.
    mapping(address => uint256) public signerSignatureIndex;

    /// @notice Mapping of cancelled Trades/Coupons, keyed by keccak256(abi.encode(signer, EIP-712 digest)).
    /// Keying on the digest instead of the raw signature bytes makes cancellations immune to signature malleability.
    /// @dev Name kept for ABI/storage-layout stability.
    mapping(bytes32 => bool) public cancelledSignatures;

    /// @notice Mapping of Trade/Coupon uses, keyed identically to `cancelledSignatures`.
    /// @dev Name kept for ABI/storage-layout stability.
    mapping(bytes32 => uint256) public signatureUses;

    event ContractSignatureIndexIncreased(address indexed _caller, uint256 indexed _newValue);
    event SignerSignatureIndexIncreased(address indexed _caller, uint256 indexed _newValue);
    event SignatureCancelled(address indexed _caller, bytes32 indexed _signature);

    error InvalidSignature();

    /// @notice Allows the owner of the contract to increase the contract signature index.
    /// Revokes all signatures created with a previous index.
    function increaseContractSignatureIndex() external onlyOwner {
        uint256 newIndex = ++contractSignatureIndex;

        emit ContractSignatureIndexIncreased(_msgSender(), newIndex);
    }

    /// @notice Allows the signer to increase their signature index.
    /// Revokes all signatures created by the signer with a previous index.
    function increaseSignerSignatureIndex() external {
        address caller = _msgSender();
        uint256 newIndex = ++signerSignatureIndex[caller];

        emit SignerSignatureIndexIncreased(caller, newIndex);
    }

    /// @dev Cancels a Trade/Coupon regardless of how its signature is encoded.
    /// Must be called only after validating that the caller is the signer.
    /// @param _digest The EIP-712 digest of the Trade/Coupon to cancel.
    /// @param _caller The address that is canceling it (must be the signer).
    function _cancelSignature(bytes32 _digest, address _caller) internal {
        cancelledSignatures[keccak256(abi.encode(_caller, _digest))] = true;

        emit SignatureCancelled(_caller, _digest);
    }

    /// @dev Verifies that a signature has been signed by a particular signer.
    /// @param _typeHash The type hash.
    /// @param _signature The signature.
    /// @param _signer The signer who is supposed to have signed the signature.
    function _verifySignature(bytes32 _typeHash, bytes calldata _signature, address _signer) internal view {
        if (!SignatureChecker.isValidSignatureNow(_signer, _hashTypedDataV4(_typeHash), _signature)) {
            revert InvalidSignature();
        }
    }
}
