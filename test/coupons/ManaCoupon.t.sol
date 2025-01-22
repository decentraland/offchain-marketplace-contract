// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {ManaCoupon} from "src/coupons/ManaCoupon.sol";

contract ManaCouponHarness is ManaCoupon {}

contract ManaCouponTests is Test {
    function setUp() public {}
}
