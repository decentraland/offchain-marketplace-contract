// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {CouponManager} from "src/coupons/CouponManager.sol";
import {ICoupon} from "src/coupons/interfaces/ICoupon.sol";
import {MockCoupon} from "src/mocks/MockCoupon.sol";

// Import the malicious contract from the marketplace tests
contract MaliciousContractWithCorrectMagicValue {
    function isValidSignature(bytes32, bytes memory) external pure returns (bytes4) {
        // Return the correct ERC1271 magic value (isValidSignature function selector)
        return 0x1626ba7e;
    }
}

contract CouponManagerHarness is CouponManager {
    constructor(address _marketplace, address _owner, address[] memory _allowedCoupons) CouponManager(_marketplace, _owner, _allowedCoupons) {}

    function eip712CouponHash(Coupon calldata _coupon) external view returns (bytes32) {
        return _hashTypedDataV4(_hashCoupon(_coupon));
    }
}

abstract contract CouponsTests is Test {
    address marketplace;
    address owner;
    address allowedCoupon;
    address other;
    VmSafe.Wallet signer;
    VmSafe.Wallet metaTxSigner;
    CouponManagerHarness couponManager;
    ICoupon mockCoupon;

    error OwnableUnauthorizedAccount(address account);
    error InvalidSignature();

    function setUp() public {
        marketplace = address(1);
        owner = address(2);
        mockCoupon = new MockCoupon();
        allowedCoupon = address(mockCoupon);
        other = address(4);
        signer = vm.createWallet("signer");
        metaTxSigner = vm.createWallet("metaTxSigner");

        address[] memory allowedCoupons = new address[](1);
        allowedCoupons[0] = allowedCoupon;

        couponManager = new CouponManagerHarness(marketplace, owner, allowedCoupons);
    }

    function signCoupon(CouponManagerHarness.Coupon memory _coupon) internal view returns (bytes memory) {
        // Set the signer field to ensure the signature is bound to the correct signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.privateKey, couponManager.eip712CouponHash(_coupon));
        return abi.encodePacked(r, s, v);
    }
}

contract SetupTests is CouponsTests {
    function test_SetUpState() public view {
        assertEq(couponManager.marketplace(), marketplace);
        assertEq(couponManager.owner(), owner);
        assertEq(couponManager.allowedCoupons(allowedCoupon), true);
        assertEq(couponManager.allowedCoupons(address(4)), false);
    }
}

contract UpdateMarketplaceTests is CouponsTests {
    event MarketplaceUpdated(address indexed _caller, address indexed _marketplace);

    function test_RevertsIfCallerIsNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, other));
        couponManager.updateMarketplace(marketplace);
    }

    function test_UpdatesTheMarketplace() public {
        vm.prank(owner);
        vm.expectEmit(address(couponManager));
        emit MarketplaceUpdated(owner, other);
        couponManager.updateMarketplace(other);
        assertEq(couponManager.marketplace(), other);
    }
}

contract UpdateAllowedCouponsTests is CouponsTests {
    event AllowedCouponsUpdated(address indexed _caller, address indexed _coupon, bool _value);

    error LengthMissmatch();

    function test_RevertsIfCallerIsNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, other));
        couponManager.updateAllowedCoupons(new address[](0), new bool[](0));
    }

    function test_RevertsIfLengthsMismatch() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(LengthMissmatch.selector));
        couponManager.updateAllowedCoupons(new address[](1), new bool[](0));

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(LengthMissmatch.selector));
        couponManager.updateAllowedCoupons(new address[](0), new bool[](1));
    }

    function test_UpdatesAllowedCoupons() public {
        assertEq(couponManager.allowedCoupons(allowedCoupon), true);
        assertEq(couponManager.allowedCoupons(other), false);

        address[] memory allowedCoupons = new address[](2);
        allowedCoupons[0] = allowedCoupon;
        allowedCoupons[1] = other;

        bool[] memory values = new bool[](2);
        values[0] = false;
        values[1] = true;

        vm.prank(owner);
        vm.expectEmit(address(couponManager));
        emit AllowedCouponsUpdated(owner, allowedCoupon, false);
        vm.expectEmit(address(couponManager));
        emit AllowedCouponsUpdated(owner, other, true);
        couponManager.updateAllowedCoupons(allowedCoupons, values);

        assertEq(couponManager.allowedCoupons(allowedCoupon), false);
        assertEq(couponManager.allowedCoupons(other), true);
    }
}

contract ApplyCouponTests is CouponsTests {
    event CouponApplied(address indexed _caller, bytes32 indexed _tradeSignature, bytes32 indexed _couponSignature, CouponManagerHarness.Coupon _coupon);

    error UnauthorizedCaller(address _caller);
    error CouponNotAllowed(address _coupon);
    error Expired();
    error SignatureOveruse();

    function test_RevertsIfCallerIsNotTheMarketplace() public {
        CouponManagerHarness.Trade memory trade;
        CouponManagerHarness.Coupon memory coupon;

        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(UnauthorizedCaller.selector, other));
        couponManager.applyCoupon(trade, coupon);
    }

    function test_RevertsIfCouponImplementationIsNotAllowed() public {
        CouponManagerHarness.Trade memory trade;
        CouponManagerHarness.Coupon memory coupon;
        coupon.couponAddress = other;

        vm.prank(marketplace);
        vm.expectRevert(abi.encodeWithSelector(CouponNotAllowed.selector, other));
        couponManager.applyCoupon(trade, coupon);
    }

    function test_RevertsIfCheckFails() public {
        CouponManagerHarness.Trade memory trade;
        CouponManagerHarness.Coupon memory coupon;
        coupon.couponAddress = allowedCoupon;

        vm.prank(marketplace);
        vm.expectRevert(SignatureOveruse.selector);
        couponManager.applyCoupon(trade, coupon);
    }

    function test_RevertsIfSignatureIsInvalid() public {
        CouponManagerHarness.Trade memory trade;
        trade.signer = other;
        CouponManagerHarness.Coupon memory coupon;
        coupon.couponAddress = allowedCoupon;
        coupon.checks.expiration = block.timestamp;
        coupon.checks.uses = 1;
        coupon.signature = signCoupon(coupon);

        vm.prank(marketplace);
        vm.expectRevert(InvalidSignature.selector);
        couponManager.applyCoupon(trade, coupon);
    }

    function test_RevertsIfSignatureHasAlreadyBeenUsed() public {
        CouponManagerHarness.Trade memory trade;
        trade.signer = signer.addr;

        CouponManagerHarness.Coupon memory coupon;
        coupon.couponAddress = allowedCoupon;
        coupon.checks.expiration = block.timestamp;
        coupon.checks.uses = 1;
        coupon.signature = signCoupon(coupon);

        vm.prank(marketplace);
        couponManager.applyCoupon(trade, coupon);

        vm.prank(marketplace);
        vm.expectRevert(SignatureOveruse.selector);
        couponManager.applyCoupon(trade, coupon);
    }

    function test_AppliesTheCouponToTheTrade() public {
        CouponManagerHarness.Trade memory trade;
        trade.signer = signer.addr;
        CouponManagerHarness.Coupon memory coupon;
        coupon.couponAddress = allowedCoupon;
        coupon.checks.expiration = block.timestamp;
        coupon.checks.uses = 1;
        coupon.signature = signCoupon(coupon);

        bytes32 hashedCouponSignatureWithSigner = keccak256(abi.encode(signer.addr, keccak256(coupon.signature)));

        assertEq(couponManager.signatureUses(hashedCouponSignatureWithSigner), 0);

        vm.prank(marketplace);
        vm.expectEmit(address(couponManager));
        emit CouponApplied(marketplace, keccak256(trade.signature), keccak256(coupon.signature), coupon);
        CouponManagerHarness.Trade memory updatedTrade = couponManager.applyCoupon(trade, coupon);
        // Mock coupon implementation updates the signer of the trade to address(1337).
        assertEq(updatedTrade.signer, address(1337));
        assertEq(couponManager.signatureUses(hashedCouponSignatureWithSigner), 1);
    }
}

contract CancelSignatureTestsCouponManager is CouponsTests {
    event SignatureCancelled(address indexed _caller, bytes32 indexed _signature);
    
    error SignatureOveruse();

    function test_CanSendEmptyListOfCoupons() public {
        vm.prank(other);
        couponManager.cancelSignature(new CouponManagerHarness.Coupon[](0));
    }

    function test_SignatureCancelled() public {
        CouponManagerHarness.Coupon[] memory couponList = new CouponManagerHarness.Coupon[](1);
        couponList[0].signature = signCoupon(couponList[0]);

        bytes32 hashedSignature = keccak256(couponList[0].signature);
        bytes32 cancellationKey = keccak256(abi.encode(signer.addr, hashedSignature));

        assertEq(couponManager.cancelledSignatures(cancellationKey), false);

        vm.prank(signer.addr);
        vm.expectEmit(address(couponManager));
        emit SignatureCancelled(signer.addr, hashedSignature);
        couponManager.cancelSignature(couponList);

        assertEq(couponManager.cancelledSignatures(cancellationKey), true);
    }

    function test_MultipleSignaturesCancelled() public {
        CouponManagerHarness.Coupon[] memory couponList = new CouponManagerHarness.Coupon[](2);
        couponList[0].checks.expiration = block.timestamp;
        couponList[0].signature = signCoupon(couponList[0]);
        couponList[1].checks.expiration = block.timestamp + 1;
        couponList[1].signature = signCoupon(couponList[1]);

        bytes32 hashedSignature1 = keccak256(couponList[0].signature);
        bytes32 hashedSignature2 = keccak256(couponList[1].signature);
        bytes32 cancellationKey1 = keccak256(abi.encode(signer.addr, hashedSignature1));
        bytes32 cancellationKey2 = keccak256(abi.encode(signer.addr, hashedSignature2));

        assertNotEq(hashedSignature1, hashedSignature2);

        assertEq(couponManager.cancelledSignatures(cancellationKey1), false);
        assertEq(couponManager.cancelledSignatures(cancellationKey2), false);

        vm.prank(signer.addr);
        vm.expectEmit(address(couponManager));
        emit SignatureCancelled(signer.addr, hashedSignature1);
        vm.expectEmit(address(couponManager));
        emit SignatureCancelled(signer.addr, hashedSignature2);
        couponManager.cancelSignature(couponList);

        assertEq(couponManager.cancelledSignatures(cancellationKey1), true);
        assertEq(couponManager.cancelledSignatures(cancellationKey2), true);
    }

    function test_CanCancelTheSameSignatureMultipleTimes() public {
        CouponManagerHarness.Coupon[] memory couponList = new CouponManagerHarness.Coupon[](2);
        couponList[0].signature = signCoupon(couponList[0]);
        couponList[1].signature = signCoupon(couponList[1]);

        bytes32 hashedSignature1 = keccak256(couponList[0].signature);
        bytes32 hashedSignature2 = keccak256(couponList[1].signature);
        bytes32 cancellationKey1 = keccak256(abi.encode(signer.addr, hashedSignature1));
        bytes32 cancellationKey2 = keccak256(abi.encode(signer.addr, hashedSignature2));

        assertEq(hashedSignature1, hashedSignature2);

        assertEq(couponManager.cancelledSignatures(cancellationKey1), false);
        assertEq(couponManager.cancelledSignatures(cancellationKey2), false);

        vm.prank(signer.addr);
        vm.expectEmit(address(couponManager));
        emit SignatureCancelled(signer.addr, hashedSignature1);
        vm.expectEmit(address(couponManager));
        emit SignatureCancelled(signer.addr, hashedSignature2);
        couponManager.cancelSignature(couponList);

        assertEq(couponManager.cancelledSignatures(cancellationKey1), true);
        assertEq(couponManager.cancelledSignatures(cancellationKey2), true);
    }

    function test_AnyoneCanCancelAnySignature() public {
        CouponManagerHarness.Coupon[] memory couponList = new CouponManagerHarness.Coupon[](1);
        couponList[0].signature = signCoupon(couponList[0]);

        bytes32 hashedSignature = keccak256(couponList[0].signature);
        bytes32 cancellationKey = keccak256(abi.encode(other, hashedSignature));

        assertEq(couponManager.cancelledSignatures(cancellationKey), false);

        // Anyone can cancel any signature (DoS prevention)
        vm.prank(other);
        couponManager.cancelSignature(couponList);

        assertEq(couponManager.cancelledSignatures(cancellationKey), true);
    }

    function test_CancelCouponByNonSignerDoesNotPreventThirdPartyFromUsing() public {
        // Create a third party who will use the coupon
        address thirdParty = makeAddr("thirdParty");
        
        CouponManagerHarness.Coupon[] memory couponList = new CouponManagerHarness.Coupon[](1);
        couponList[0].signature = signCoupon(couponList[0]);

        bytes32 hashedSignature = keccak256(couponList[0].signature);
        bytes32 signerCancellationKey = keccak256(abi.encode(signer.addr, hashedSignature));
        bytes32 otherCancellationKey = keccak256(abi.encode(other, hashedSignature));
        bytes32 thirdPartyCancellationKey = keccak256(abi.encode(thirdParty, hashedSignature));

        // Initially, no cancellations exist
        assertEq(couponManager.cancelledSignatures(signerCancellationKey), false);
        assertEq(couponManager.cancelledSignatures(otherCancellationKey), false);
        assertEq(couponManager.cancelledSignatures(thirdPartyCancellationKey), false);

        // Someone else cancels the coupon signature (they didn't create it)
        vm.prank(other);
        couponManager.cancelSignature(couponList);

        // The cancellation is tied to 'other', not the original signer or third party
        assertEq(couponManager.cancelledSignatures(signerCancellationKey), false);
        assertEq(couponManager.cancelledSignatures(otherCancellationKey), true);
        assertEq(couponManager.cancelledSignatures(thirdPartyCancellationKey), false);
    }

    function test_MaliciousContractCanReuseValidSignatureForSameCouponAndConsumeUses() public {
        // Deploy a malicious contract that implements ERC1271
        address sc = address(new MaliciousContractWithCorrectMagicValue());
        
        // Create a legitimate coupon with 1 use, signed by the real user
        CouponManagerHarness.Coupon memory legitimateCoupon;
        legitimateCoupon.couponAddress = allowedCoupon;
        legitimateCoupon.checks.expiration = block.timestamp + 1;
        legitimateCoupon.checks.uses = 1;
        legitimateCoupon.signature = signCoupon(legitimateCoupon);
        
        // Create a coupon with same signature
        // The malicious contract can reuse the valid signature for the same coupon
        CouponManagerHarness.Coupon memory fakeCoupon;
        fakeCoupon.couponAddress = allowedCoupon;
        fakeCoupon.checks.expiration = block.timestamp + 1;
        fakeCoupon.checks.uses = 1;
        fakeCoupon.signature = signCoupon(fakeCoupon);
        
        // Initially, the signature has 0 uses
        bytes32 hashedSignature = keccak256(abi.encode(signer.addr, keccak256(legitimateCoupon.signature)));
        bytes32 hashedFakeSignature = keccak256(abi.encode(sc, keccak256(fakeCoupon.signature)));
        assertNotEq(hashedSignature, hashedFakeSignature);
        assertEq(couponManager.signatureUses(hashedSignature), 0);
        assertEq(couponManager.signatureUses(hashedFakeSignature), 0);
        
        // The malicious contract uses the signature for the same coupon
        // This should succeed because the signature is valid and the malicious contract
        // can bypass signature verification by implementing ERC1271
        CouponManagerHarness.Trade memory trade;
        trade.signer = sc; // Set the trade signer to match the coupon signer
        vm.prank(marketplace);
        couponManager.applyCoupon(trade, fakeCoupon);
        
        // The signature use count is now 1
        assertEq(couponManager.signatureUses(hashedSignature), 0);
        assertEq(couponManager.signatureUses(hashedFakeSignature), 1);
        
        // Now when the legitimate user tries to use their original coupon, it should fail
        // because the signature has already been used (SignatureOveruse error)
        trade.signer = signer.addr; // Set the trade signer to match the coupon signer
        vm.prank(marketplace);
        couponManager.applyCoupon(trade, legitimateCoupon);

        assertEq(couponManager.signatureUses(hashedSignature), 1);
        assertEq(couponManager.signatureUses(hashedFakeSignature), 1);
    }

}
