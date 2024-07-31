// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CommonTypes} from "src/common/CommonTypes.sol";

/// @notice Hashing of the common types, used for EIP712 signature verification.
abstract contract CommonTypesHashing is CommonTypes {
    // keccak256("ExternalCheck(address contractAddress,bytes4 selector,bytes value,bool required)")
    bytes32 private constant EXTERNAL_CHECK_TYPE_HASH = 0x8d4afe924d276922e1a624d4cc4d5b316cb369a5d290db2fae6417ec282d01f8;

    // keccak256("Checks(uint256 uses,uint256 expiration,uint256 effective,bytes32 salt,uint256 contractSignatureIndex,uint256 signerSignatureIndex,bytes32 allowedRoot,ExternalCheck[] externalChecks)ExternalCheck(address contractAddress,bytes4 selector,bytes value,bool required)")
    bytes32 private constant CHECKS_TYPE_HASH = 0xcae85973b802c2104c84d94b18a0a8a13a0576322547fe2fab563e83849ce641;

    function _hashExternalChecks(ExternalCheck[] calldata _externalChecks) private pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](_externalChecks.length);

        for (uint256 i = 0; i < hashes.length; i++) {
            ExternalCheck calldata externalCheck = _externalChecks[i];

            hashes[i] = keccak256(
                abi.encode(
                    EXTERNAL_CHECK_TYPE_HASH,
                    externalCheck.contractAddress,
                    externalCheck.selector,
                    keccak256(externalCheck.value),
                    externalCheck.required
                )
            );
        }

        return keccak256(abi.encodePacked(hashes));
    }

    function _hashChecks(Checks calldata _checks) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                CHECKS_TYPE_HASH,
                _checks.uses,
                _checks.expiration,
                _checks.effective,
                _checks.salt,
                _checks.contractSignatureIndex,
                _checks.signerSignatureIndex,
                _checks.allowedRoot,
                _hashExternalChecks(_checks.externalChecks)
            )
        );
    }
}
