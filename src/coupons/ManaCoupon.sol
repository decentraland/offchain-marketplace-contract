// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ICoupon} from "src/coupons/interfaces/ICoupon.sol";
import {MarketplaceTypes} from "src/marketplace/MarketplaceTypes.sol";
import {CouponTypes} from "src/coupons/CouponTypes.sol";

contract ManaCoupon is ICoupon, MarketplaceTypes, CouponTypes {
    function applyCoupon(
        Trade calldata _trade,
        Coupon calldata // _coupon
    ) external pure returns (Trade memory) {
        return _trade;
    }
}
