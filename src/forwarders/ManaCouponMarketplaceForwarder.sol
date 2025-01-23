// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract ManaCouponMarketplaceForwarder is AccessControl, Pausable {
    using ECDSA for bytes32;

    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    struct ManaCoupon {
        uint256 amount;
        uint256 expiration;
        uint256 effective;
        bytes32 salt;
        bytes signature;
    }

    mapping(bytes32 => uint256) public amountUsedFromCoupon;
    address public marketplace;

    error InvalidSigner(address _signer);
    error CouponExpired(uint256 _currentTime);
    error CouponIneffective(uint256 _currentTime);
    error MarketplaceCallFailed();

    constructor(address _caller, address _pauser, address _signer, address _marketplace) {
        _grantRole(CALLER_ROLE, _caller);
        _grantRole(PAUSER_ROLE, _pauser);
        _grantRole(SIGNER_ROLE, _signer);

        marketplace = _marketplace;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function forward(ManaCoupon calldata _coupon, bytes calldata _executeMetaTx) external onlyRole(CALLER_ROLE) whenNotPaused {
        bytes32 hashedCoupon = keccak256(abi.encode(_coupon.amount, _coupon.expiration, _coupon.effective, _coupon.salt));
        address signer = hashedCoupon.recover(_coupon.signature);

        if (!hasRole(SIGNER_ROLE, signer)) {
            revert InvalidSigner(signer);
        }

        if (_coupon.expiration < block.timestamp) {
            revert CouponExpired(block.timestamp);
        }

        if (_coupon.effective > block.timestamp) {
            revert CouponIneffective(block.timestamp);
        }

        amountUsedFromCoupon[keccak256(_coupon.signature)] += _coupon.amount;

        (bool success,) = marketplace.call(_executeMetaTx);

        if (!success) {
            revert MarketplaceCallFailed();
        }
    }
}
