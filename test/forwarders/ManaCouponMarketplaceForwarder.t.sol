// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {ManaCouponMarketplaceForwarder} from "src/forwarders/ManaCouponMarketplaceForwarder.sol";

contract ManaCouponMarketplaceForwarderHarness is ManaCouponMarketplaceForwarder {
    constructor(address _caller, address _pauser, address _signer) ManaCouponMarketplaceForwarder(_caller, _pauser, _signer) {}
}

contract ManaCouponMarketplaceForwarderTests is Test {
    address other;
    address caller;
    address pauser;
    VmSafe.Wallet signer;
    VmSafe.Wallet otherSigner;

    ManaCouponMarketplaceForwarderHarness forwarder;
    ManaCouponMarketplaceForwarderHarness.ManaCoupon coupon;

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error EnforcedPause();
    error InvalidSigner(address _signer);
    error CouponExpired(uint256 _currentTime);
    error CouponIneffective(uint256 _currentTime);

    function _sign(uint256 _pk, ManaCouponMarketplaceForwarderHarness.ManaCoupon memory _coupon) private pure returns (bytes memory) {
        bytes32 hashedCoupon = keccak256(abi.encode(_coupon.amount, _coupon.expiration, _coupon.effective));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk, hashedCoupon);

        return abi.encodePacked(r, s, v);
    }

    function setUp() public {
        other = makeAddr("other");
        caller = makeAddr("caller");
        pauser = makeAddr("pauser");
        signer = vm.createWallet("signer");
        otherSigner = vm.createWallet("otherSigner");

        coupon.amount = 100;
        coupon.expiration = block.timestamp + 1 days;
        coupon.signature = _sign(signer.privateKey, coupon);

        forwarder = new ManaCouponMarketplaceForwarderHarness(caller, pauser, signer.addr);
    }

    function test_pause_RevertsIfSenderIsNotPauser() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, other, forwarder.PAUSER_ROLE()));
        vm.prank(other);
        forwarder.pause();
    }

    function test_unpause_RevertsIfSenderIsNotPauser() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, other, forwarder.PAUSER_ROLE()));
        vm.prank(other);
        forwarder.unpause();
    }

    function test_forward_RevertsIfSenderIsNotAuthorizedCaller() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, other, forwarder.CALLER_ROLE()));
        vm.prank(other);
        forwarder.forward(coupon);
    }

    function test_forward_RevertsIfPaused() public {
        vm.prank(pauser);
        forwarder.pause();

        vm.expectRevert(EnforcedPause.selector);
        vm.prank(caller);
        forwarder.forward(coupon);
    }

    function test_forward_RevertsIfMessageSignerIsInvalid() public {
        coupon.signature = _sign(otherSigner.privateKey, coupon);

        vm.expectRevert(abi.encodeWithSelector(InvalidSigner.selector, otherSigner.addr));
        vm.prank(caller);
        forwarder.forward(coupon);
    }

    function test_forward_AddsTheCouponAmountToTheConsumedCouponsMapping() public {
        vm.prank(caller);
        forwarder.forward(coupon);

        assertEq(forwarder.consumedCoupons(keccak256(coupon.signature)), coupon.amount);
    }

    function test_forward_RevertsIfCouponIsExpired() public {
        coupon.expiration = block.timestamp - 1;
        coupon.signature = _sign(signer.privateKey, coupon);

        vm.expectRevert(abi.encodeWithSelector(CouponExpired.selector, block.timestamp));
        vm.prank(caller);
        forwarder.forward(coupon);
    }

    function test_forward_RevertsIfCouponIsInnefective() public {
        coupon.effective = block.timestamp + 1 days;
        coupon.signature = _sign(signer.privateKey, coupon);

        vm.expectRevert(abi.encodeWithSelector(CouponIneffective.selector, block.timestamp));
        vm.prank(caller);
        forwarder.forward(coupon);
    }
}
