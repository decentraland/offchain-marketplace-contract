// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Verifications} from "src/common/Verifications.sol";
import {EIP712} from "src/common/EIP712.sol";
import {ICoupon} from "src/coupons/interfaces/ICoupon.sol";
import {CouponTypesHashing} from "src/coupons/CouponTypesHashing.sol";
import {MarketplaceTypes} from "src/marketplace/MarketplaceTypes.sol";

/// @notice Contract that allows applying Coupons to Trades.
/// It holds the logic to control which Coupons are allowed to be applied.
/// It also manages the Coupon signatures and their uses. This is useful to be able to add or remove new Coupons while still using the same EIP712 domain.
contract CouponManager is Verifications, CouponTypesHashing, MarketplaceTypes {
    /// @notice The address of the Marketplace that will be able to apply Coupons.
    /// Only this address will be able to apply Coupons.
    address public marketplace;

    /// @notice Mapping of the allowed Coupon contracts.
    /// If a Coupon is not in this mapping, it will not be allowed to be applied.
    mapping(address => bool) public allowedCoupons;

    event MarketplaceUpdated(address indexed _caller, address indexed _marketplace);
    event AllowedCouponsUpdated(address indexed _caller, address indexed _coupon, bool _value);
    /// @dev Emitted when a Coupon is applied to a Trade.
    /// @param _caller The address executing the Trade, as forwarded by the marketplace (not the marketplace itself).
    /// @param _tradeSignature keccak256 of the trade signature bytes (malleable; kept for indexing continuity).
    /// @param _couponSignature keccak256 of the coupon signature bytes (malleable; kept for indexing continuity).
    /// @param _tradeDigest The signed EIP-712 digest of the trade, as provided by the calling marketplace.
    /// Equals `Traded._tradeDigest` in the same transaction.
    /// @param _couponDigest The signed EIP-712 digest of the coupon; the canonical coupon identifier.
    event CouponApplied(
        address indexed _caller,
        bytes32 indexed _tradeSignature,
        bytes32 indexed _couponSignature,
        bytes32 _tradeDigest,
        bytes32 _couponDigest,
        Coupon _coupon
    );

    error LengthMissmatch();
    error UnauthorizedCaller(address _caller);
    error CouponNotAllowed(address _coupon);

    /// @param _marketplace The address of the Marketplace that will be able to apply Coupons.
    /// @param _owner The owner of the contract.
    /// @param _allowedCoupons The initial list of allowed Coupons.
    constructor(address _marketplace, address _owner, address[] memory _allowedCoupons) EIP712("CouponManager", "1.0.0") Ownable(_owner) {
        _updateMarketplace(_marketplace);

        for (uint256 i = 0; i < _allowedCoupons.length; i++) {
            _updateAllowedCoupons(_allowedCoupons[i], true);
        }
    }

    /// @notice Updates the address of the Marketplace that will be able to apply Coupons.
    function updateMarketplace(address _marketplace) external onlyOwner {
        _updateMarketplace(_marketplace);
    }

    /// @notice Updates the list of allowed Coupons.
    function updateAllowedCoupons(address[] calldata _coupons, bool[] calldata _values) external onlyOwner {
        if (_coupons.length != _values.length) {
            revert LengthMissmatch();
        }

        for (uint256 i = 0; i < _coupons.length; i++) {
            _updateAllowedCoupons(_coupons[i], _values[i]);
        }
    }

    /// @notice Revokes the signatures of all provided coupons.
    /// The caller must be the signer of those coupons.
    /// @param _coupons The list of coupon signatures to be canceled.
    function cancelSignature(Coupon[] calldata _coupons) external {
        address caller = _msgSender();

        for (uint256 i = 0; i < _coupons.length; i++) {
            Coupon calldata coupon = _coupons[i];

            _cancelSignature(_hashTypedDataV4(_hashCoupon(coupon)), caller);
        }
    }

    /// @notice Applies a Coupon to a Trade.
    /// @param _trade The Trade to apply the Coupon to.
    /// @param _coupon The Coupon to apply.
    /// @param _tradeDigest The signed EIP-712 digest of the Trade. Not used for validation; only surfaced in the
    /// CouponApplied event, so it is trusted from the marketplace (the only authorized caller).
    /// @param _caller The address executing the Trade on the marketplace, forwarded so the Coupon Checks
    /// (allowedRoot, externalChecks) are evaluated against the actual user instead of the marketplace contract.
    /// Trusted from the marketplace (the only authorized caller).
    /// @return The Trade with the Coupon applied.
    function applyCoupon(Trade calldata _trade, Coupon calldata _coupon, bytes32 _tradeDigest, address _caller) external returns (Trade memory) {
        // Only the marketplace is allowed to apply Coupons.
        if (_msgSender() != marketplace) {
            revert UnauthorizedCaller(_msgSender());
        }

        address couponAddress = _coupon.couponAddress;

        // Fails if the coupon has not been allowed.
        if (!allowedCoupons[couponAddress]) {
            revert CouponNotAllowed(couponAddress);
        }

        address signer = _trade.signer;
        bytes32 couponDigest = _hashTypedDataV4(_hashCoupon(_coupon));
        bytes32 hashedCouponWithSigner = keccak256(abi.encode(signer, couponDigest));
        uint256 currentSignatureUses = signatureUses[hashedCouponWithSigner];

        // Verify that the check values provided in the Coupon are correct.
        _verifyChecks(_coupon.checks, hashedCouponWithSigner, currentSignatureUses, signer, _caller);
        // Verify that the Coupon signature is valid.
        _verifyCouponSignature(_coupon, signer);

        // Raw-signature hashes are emitted only as event identifiers, hashed inline to keep the stack shallow.
        emit CouponApplied(_caller, keccak256(_trade.signature), keccak256(_coupon.signature), _tradeDigest, couponDigest, _coupon);

        // Increase the amount of uses of the Coupon signature.
        signatureUses[hashedCouponWithSigner]++;

        // Apply the Coupon and return the modified Trade.
        return ICoupon(couponAddress).applyCoupon(_trade, _coupon);
    }

    function _verifyCouponSignature(Coupon calldata _coupon, address _signer) private view {
        _verifySignature(_hashCoupon(_coupon), _coupon.signature, _signer);
    }

    function _updateMarketplace(address _marketplace) private {
        marketplace = _marketplace;

        emit MarketplaceUpdated(_msgSender(), _marketplace);
    }

    function _updateAllowedCoupons(address _coupon, bool _value) private {
        allowedCoupons[_coupon] = _value;

        emit AllowedCouponsUpdated(_msgSender(), _coupon, _value);
    }
}
