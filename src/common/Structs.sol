// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

abstract contract Structs {
    // keccak256("ExternalCheck(address contractAddress,bytes4 selector,uint256 value,bool required)")
    bytes32 internal constant EXTERNAL_CHECK_TYPE_HASH = 0xdf361982fbc6415130c9d78e2e25ec087cf4812d4c0714d41cc56537ee15ac24;

    // keccak256("Checks(uint256 uses,uint256 expiration,uint256 effective,bytes32 salt,uint256 contractSignatureIndex,uint256 signerSignatureIndex,address[] allowed,ExternalCheck[] externalChecks)ExternalCheck(address contractAddress,bytes4 selector,uint256 value,bool required)")
    bytes32 internal constant CHECKS_TYPE_HASH = 0x2f962336c5429beb00c5ed44703aebcb2aaf2600ba276ef74dc82ca3bc073651;

    // keccak256("AssetWithoutBeneficiary(uint256 assetType,address contractAddress,uint256 value,bytes extra)")
    bytes32 internal constant ASSET_WO_BENEFICIARY_TYPE_HASH = 0x7be57332caf51c5f0f0fa0e7c362534d22d81c0bee1ffac9b573acd336e032bd;

    // keccak256("Asset(uint256 assetType,address contractAddress,uint256 value,bytes extra,address beneficiary)")
    bytes32 internal constant ASSET_TYPE_HASH = 0xe5f9e1ebc316d1bde562c77f47da7dc2cccb903eb04f9b82e29212b96f9e57e1;

    // keccak256("Trade(Checks checks,AssetWithoutBeneficiary[] sent,Asset[] received)Asset(uint256 assetType,address contractAddress,uint256 value,bytes extra,address beneficiary)AssetWithoutBeneficiary(uint256 assetType,address contractAddress,uint256 value,bytes extra)Checks(uint256 uses,uint256 expiration,uint256 effective,bytes32 salt,uint256 contractSignatureIndex,uint256 signerSignatureIndex,address[] allowed,ExternalCheck[] externalChecks)ExternalCheck(address contractAddress,bytes4 selector,uint256 value,bool required)")
    bytes32 internal constant TRADE_TYPE_HASH = 0x6a9beda065389ec62818727007cff89069ad7a2ae71cc72612ba2b563a009bfe;

    // keccak256("Modifier(Checks checks,uint256 modifierType,bytes data)Checks(uint256 uses,uint256 expiration,uint256 effective,bytes32 salt,uint256 contractSignatureIndex,uint256 signerSignatureIndex,address[] allowed,ExternalCheck[] externalChecks)ExternalCheck(address contractAddress,bytes4 selector,uint256 value,bool required)")
    bytes32 internal constant MODIFIER_TYPE_HASH = 0x5f8554ec0f2e85d95d0a1c8b4b287d433c736606ae28b55167c9bc7caa0c4a19;

    struct ExternalCheck {
        address contractAddress;
        bytes4 selector;
        uint256 value;
        bool required;
    }

    struct Checks {
        uint256 uses;
        uint256 expiration;
        uint256 effective;
        bytes32 salt;
        uint256 contractSignatureIndex;
        uint256 signerSignatureIndex;
        address[] allowed;
        ExternalCheck[] externalChecks;
    }

    struct Asset {
        uint256 assetType;
        address contractAddress;
        uint256 value;
        address beneficiary;
        bytes extra;
        bytes unverifiedExtra;
    }

    struct Trade {
        address signer;
        bytes signature;
        Checks checks;
        Asset[] sent;
        Asset[] received;
    }

    struct Modifier {
        bytes signature;
        Checks checks;
        uint256 modifierType;
        bytes data;
    }

    function _hashExternalChecks(ExternalCheck[] memory _externalChecks) internal pure returns (bytes32[] memory) {
        bytes32[] memory hashes = new bytes32[](_externalChecks.length);

        for (uint256 i = 0; i < hashes.length; i++) {
            ExternalCheck memory externalCheck = _externalChecks[i];

            hashes[i] = keccak256(
                abi.encode(
                    EXTERNAL_CHECK_TYPE_HASH, externalCheck.contractAddress, externalCheck.selector, externalCheck.value, externalCheck.required
                )
            );
        }

        return hashes;
    }

    function _hashChecks(Checks memory _checks) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                CHECKS_TYPE_HASH,
                _checks.uses,
                _checks.expiration,
                _checks.effective,
                _checks.salt,
                _checks.contractSignatureIndex,
                _checks.signerSignatureIndex,
                keccak256(abi.encodePacked(_checks.allowed)),
                keccak256(abi.encodePacked(_hashExternalChecks(_checks.externalChecks)))
            )
        );
    }

    function _hashAssetsWithoutBeneficiary(Asset[] memory _assets) internal pure returns (bytes32[] memory) {
        bytes32[] memory hashes = new bytes32[](_assets.length);

        for (uint256 i = 0; i < hashes.length; i++) {
            Asset memory asset = _assets[i];

            hashes[i] =
                keccak256(abi.encode(ASSET_WO_BENEFICIARY_TYPE_HASH, asset.assetType, asset.contractAddress, asset.value, keccak256(asset.extra)));
        }

        return hashes;
    }

    function _hashAssets(Asset[] memory _assets) internal pure returns (bytes32[] memory) {
        bytes32[] memory hashes = new bytes32[](_assets.length);

        for (uint256 i = 0; i < hashes.length; i++) {
            Asset memory asset = _assets[i];

            hashes[i] =
                keccak256(abi.encode(ASSET_TYPE_HASH, asset.assetType, asset.contractAddress, asset.value, keccak256(asset.extra), asset.beneficiary));
        }

        return hashes;
    }

    function _hashTrade(Trade memory _trade) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                TRADE_TYPE_HASH,
                keccak256(abi.encodePacked(_hashChecks(_trade.checks))),
                keccak256(abi.encodePacked(_hashAssetsWithoutBeneficiary(_trade.sent))),
                keccak256(abi.encodePacked(_hashAssets(_trade.received)))
            )
        );
    }

    function _hashModifier(Modifier memory _modifier) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                MODIFIER_TYPE_HASH, keccak256(abi.encodePacked(_hashChecks(_modifier.checks))), _modifier.modifierType, keccak256(_modifier.data)
            )
        );
    }
}