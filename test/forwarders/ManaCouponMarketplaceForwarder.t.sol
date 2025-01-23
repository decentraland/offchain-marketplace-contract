// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {ManaCouponMarketplaceForwarder} from "src/forwarders/ManaCouponMarketplaceForwarder.sol";
import {DecentralandMarketplacePolygon} from "src/marketplace/DecentralandMarketplacePolygon.sol";

contract ManaCouponMarketplaceForwarderHarness is ManaCouponMarketplaceForwarder {
    constructor(address _owner, address _pauser, address _signer, DecentralandMarketplacePolygon _marketplace)
        ManaCouponMarketplaceForwarder(_owner, _pauser, _signer, _marketplace)
    {}
}

contract ManaCouponMarketplaceForwarderTests is Test {
    address other;
    address pauser;
    VmSafe.Wallet signer;
    VmSafe.Wallet otherSigner;
    address owner;
    VmSafe.Wallet metaTxSigner;

    ManaCouponMarketplaceForwarderHarness.ManaCoupon coupon;

    ManaCouponMarketplaceForwarderHarness forwarder;
    DecentralandMarketplacePolygon marketplace;

    bytes executeMetaTx;

    // Third Party Errors
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error EnforcedPause();

    // Local Errors
    error InvalidSigner(address _signer);
    error CouponExpired(uint256 _currentTime);
    error CouponIneffective(uint256 _currentTime);
    error InvalidSelector(bytes4 _selector);
    error InvalidMetaTxUser(address _user);
    error InvalidMetaTxFunctionDataSelector(bytes4 _selector);
    error MarketplaceCallFailed();

    function _sign(uint256 _pk, ManaCouponMarketplaceForwarderHarness.ManaCoupon memory _coupon) private pure returns (bytes memory) {
        bytes32 hashedCoupon = keccak256(abi.encode(_coupon.amount, _coupon.expiration, _coupon.effective, _coupon.salt));

        return _sign(_pk, hashedCoupon);
    }

    function _sign(uint256 _pk, bytes32 _hash) private pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk, _hash);

        return abi.encodePacked(r, s, v);
    }

    function _buildExecuteMetaTx() private view returns (bytes memory) {
        DecentralandMarketplacePolygon.Trade[] memory trades = new DecentralandMarketplacePolygon.Trade[](0);

        return abi.encodeWithSelector(
            marketplace.executeMetaTransaction.selector,
            metaTxSigner.addr,
            abi.encodeWithSelector(marketplace.accept.selector, trades),
            _sign(
                metaTxSigner.privateKey,
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        keccak256(
                            abi.encode(
                                0x36c25de3e541d5d970f66e4210d728721220fff5c077cc6cd008b3a0c62adab7,
                                keccak256("DecentralandMarketplacePolygon"),
                                keccak256("1.0.0"),
                                address(marketplace),
                                block.chainid
                            )
                        ),
                        keccak256(
                            abi.encode(
                                0x01ecdc01065da9f72bf56a9def24a074b7ef512994beb776867cfbc664b5b959,
                                0,
                                metaTxSigner.addr,
                                keccak256(abi.encodeWithSelector(marketplace.accept.selector, trades))
                            )
                        )
                    )
                )
            )
        );
    }

    function setUp() public {
        other = makeAddr("other");
        pauser = makeAddr("pauser");
        signer = vm.createWallet("signer");
        otherSigner = vm.createWallet("otherSigner");
        owner = makeAddr("owner");
        metaTxSigner = vm.createWallet("metaTxSigner");

        coupon.amount = 100;
        coupon.expiration = block.timestamp + 1 days;
        coupon.signature = _sign(signer.privateKey, coupon);
        coupon.beneficiary = metaTxSigner.addr;

        marketplace = new DecentralandMarketplacePolygon(owner, address(0), address(0), 0, address(0), 0, address(0), address(0), 0);
        forwarder = new ManaCouponMarketplaceForwarderHarness(owner, pauser, signer.addr, marketplace);

        executeMetaTx = _buildExecuteMetaTx();
    }

    function test_pause_RevertsIfSenderIsNotPauser() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, other, forwarder.PAUSER_ROLE()));
        vm.prank(other);
        forwarder.pause();
    }

    function test_pause_AllowsOwnerToPause() public {
        vm.prank(owner);
        forwarder.pause();
    }

    function test_unpause_RevertsIfSenderIsNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, pauser, forwarder.DEFAULT_ADMIN_ROLE()));
        vm.prank(pauser);
        forwarder.unpause();
    }

    function test_forward_RevertsIfPaused() public {
        vm.prank(pauser);
        forwarder.pause();

        vm.expectRevert(EnforcedPause.selector);
        forwarder.forward(coupon, executeMetaTx);
    }

    function test_forward_RevertsIfMessageSignerIsInvalid() public {
        coupon.signature = _sign(otherSigner.privateKey, coupon);

        vm.expectRevert(abi.encodeWithSelector(InvalidSigner.selector, otherSigner.addr));
        forwarder.forward(coupon, executeMetaTx);
    }

    function test_forward_AddsTheCouponAmountToTheAmountUsedFromCouponMapping() public {
        forwarder.forward(coupon, executeMetaTx);

        assertEq(forwarder.amountUsedFromCoupon(keccak256(coupon.signature)), coupon.amount);
    }

    function test_forward_RevertsIfCouponIsExpired() public {
        coupon.expiration = block.timestamp - 1;
        coupon.signature = _sign(signer.privateKey, coupon);

        vm.expectRevert(abi.encodeWithSelector(CouponExpired.selector, block.timestamp));
        forwarder.forward(coupon, executeMetaTx);
    }

    function test_forward_RevertsIfCouponIsInnefective() public {
        coupon.effective = block.timestamp + 1 days;
        coupon.signature = _sign(signer.privateKey, coupon);

        vm.expectRevert(abi.encodeWithSelector(CouponIneffective.selector, block.timestamp));
        forwarder.forward(coupon, executeMetaTx);
    }

    function test_forward_ForwardsTheMetaTrxToTheMarketplace() public {
        forwarder.forward(coupon, executeMetaTx);
    }

    // function test_forward_RevertsIfMarketplaceCallFails() public {
    //     executeMetaTx = abi.encodeWithSelector(marketplace.executeMetaTransaction.selector, metaTxSigner.addr, "", "");

    //     vm.expectRevert(abi.encodeWithSelector(MarketplaceCallFailed.selector));
    //     forwarder.forward(coupon, executeMetaTx);
    // }

    function test_forward_RevertsIfExecuteMetaTxSelectorIsInvalid() public {
        bytes4 invalidSelector = bytes4(0x12345678);

        executeMetaTx = abi.encodeWithSelector(invalidSelector, address(0), "", "");

        vm.expectRevert(abi.encodeWithSelector(InvalidSelector.selector, invalidSelector));
        forwarder.forward(coupon, executeMetaTx);
    }

    function test_forward_RevertsIfMetaTxUserIsNotCouponBeneficiary() public {
        coupon.beneficiary = address(0);
        coupon.signature = _sign(signer.privateKey, coupon);

        vm.expectRevert(abi.encodeWithSelector(InvalidMetaTxUser.selector, metaTxSigner.addr));
        forwarder.forward(coupon, executeMetaTx);
    }

    function test_forward_RevertsIfExecuteMetaTxIsEmpty() public {
        vm.expectRevert();
        forwarder.forward(coupon, "");
    }

    function test_forward_RevertsIfExecuteMetaTxLengthIsLT4() public {
        vm.expectRevert();
        forwarder.forward(coupon, "123"); // 0x313233 == 3 bytes
    }

    function test_forward_RevertsIfExecuteMetaTxDataIsNotMetaTxSchema() public {
        vm.expectRevert();
        forwarder.forward(coupon, abi.encodeWithSelector(marketplace.executeMetaTransaction.selector, metaTxSigner.addr, 123));
    }

    function test_forward_RevertsIfMetaTxDataSelectorIsInvalid() public {
        bytes4 invalidSelector = bytes4(0x12345678);

        executeMetaTx = abi.encodeWithSelector(marketplace.executeMetaTransaction.selector, metaTxSigner.addr, abi.encode(invalidSelector, ""));

        vm.expectRevert(abi.encodeWithSelector(InvalidMetaTxFunctionDataSelector.selector, invalidSelector));
        forwarder.forward(coupon, executeMetaTx);
    }

    function test_forward_RevertsIfTradesCannotBeExtractedFromMetaTxData() public {
        executeMetaTx =
            abi.encodeWithSelector(marketplace.executeMetaTransaction.selector, metaTxSigner.addr, abi.encodeWithSelector(marketplace.accept.selector, 123));

        vm.expectRevert();
        forwarder.forward(coupon, executeMetaTx);
    }
}
