// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Types used by many contracts in this project.
abstract contract CommonTypes {
    /// @notice Schema of an external check.
    /// This is used to verify that certain external requirements are met.
    /// @param contractAddress The address of the contract to call.
    /// @param selector The selector of the function to call.
    /// @param value The value to pass to the function.
    /// @param required If the check is required or not.
    struct ExternalCheck {
        address contractAddress;
        bytes4 selector;
        bytes value;
        bool required;
    }

    /// @notice Schema of a check.
    /// This is used to verify that certain requirements are met.
    /// @param uses The number of times the signature can be used.
    /// @param expiration The expiration date of the signature.
    /// @param effective The effective date of the signature.
    /// @param salt A value used to make the signature unique.
    /// @param contractSignatureIndex The contract signature index required to validate the signature.
    /// @param signerSignatureIndex The signer signature index required to validate the signature.
    /// @param allowedRoot The Merkle Root of the allowed addresses. If empty, no check is performed.
    /// @param allowedProof The Merkle Proof that validates that the caller is allowed. Is not validated in the signature given that it is data used by the caller.
    /// @param externalChecks The external checks to verify.
    struct Checks {
        uint256 uses;
        uint256 expiration;
        uint256 effective;
        bytes32 salt;
        uint256 contractSignatureIndex;
        uint256 signerSignatureIndex;
        bytes32 allowedRoot;
        bytes32[] allowedProof;
        ExternalCheck[] externalChecks;
    }
}
