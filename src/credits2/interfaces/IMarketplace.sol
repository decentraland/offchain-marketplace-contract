// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

struct ExternalCheck {
    address contractAddress;
    bytes4 selector;
    bytes value;
    bool required;
}

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

struct Asset {
    uint256 assetType;
    address contractAddress;
    uint256 value;
    address beneficiary;
    bytes extra;
}

struct Trade {
    address signer;
    bytes signature;
    Checks checks;
    Asset[] sent;
    Asset[] received;
}

struct Coupon {
    bytes signature;
    Checks checks;
    address couponAddress;
    bytes data;
    bytes callerData;
}

interface IMarketplace {
    function accept(Trade[] calldata _trades) external;
    function acceptWithCoupon(Trade[] calldata _trades, Coupon[] calldata _coupons) external;
}
