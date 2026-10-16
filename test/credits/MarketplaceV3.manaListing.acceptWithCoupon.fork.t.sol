// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {CreditsManagerPolygon} from "src/credits/CreditsManagerPolygon.sol";
import {IMarketplace} from "src/credits/interfaces/IMarketplace.sol";
import {MarketplaceTypes} from "src/marketplace/MarketplaceTypes.sol";
import {CommonTypes} from "src/common/CommonTypes.sol";
import {MarketplaceTypesHashing} from "src/marketplace/MarketplaceTypesHashing.sol";
import {CouponTypes} from "src/coupons/CouponTypes.sol";
import {CouponTypesHashing} from "src/coupons/CouponTypesHashing.sol";
import {CollectionDiscountCoupon} from "src/coupons/CollectionDiscountCoupon.sol";

contract V3TradeHashing is MarketplaceTypesHashing {
    function hashTrade(Trade calldata _trade) external pure returns (bytes32) {
        return _hashTrade(_trade);
    }
}

contract V3CouponHashing is CouponTypesHashing {
    function hashCoupon(Coupon calldata _coupon) external pure returns (bytes32) {
        return _hashCoupon(_coupon);
    }
}

interface IV3SignatureIndexes {
    function contractSignatureIndex() external view returns (uint256);
    function signerSignatureIndex(address) external view returns (uint256);
    function couponManager() external view returns (address);
}

interface IMarketplaceAcceptWithCoupon {
    function acceptWithCoupon(MarketplaceTypes.Trade[] calldata _trades, CouponTypes.Coupon[] calldata _coupons) external;
}

/// Whether a creator discount coupon applies to a MANA-priced (ERC20) primary listing, not only to a
/// USD-pegged (Credits) one, on the marketplace and CouponManager live today: OffChainMarketplaceV3 and the
/// manager wired into it, forked from Polygon mainnet.
///
/// Everything is the deployed bytecode: CreditsManager, marketplace V3, its CouponManager, the
/// CollectionDiscountCoupon, MANA, and a real collection with an open V3 MANA listing. Faked: the keys (a test
/// creator and a test credits signer granted the role by the manager's admin) and the collection's `creator()`,
/// mocked to the test creator so the coupon is signed by "the creator".
contract MarketplaceV3ManaListingAcceptWithCouponForkTest is Test, IERC721Receiver {
    using MessageHashUtils for bytes32;

    uint256 constant FORK_BLOCK = 95_630_000;
    address constant MANA = 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4;
    address constant MARKETPLACE_V3 = 0xe38EF22aBe871513555cBa89adfe45aB4f548ada;
    address constant COUPON_MANAGER_V3 = 0x655fDFa91d69EA49F4Ce1a8f7F7E2622C8630813;
    address constant COLLECTION_DISCOUNT_COUPON = 0xc914507fE297b2dddd1232Ac3A8903F1c125e794;
    address constant CREDITS_MANAGER = 0x8B3A40CA1b6F5CaFC99d112a4d02E897d1FD8Cc5;
    address constant CREDITS_MANAGER_ADMIN = 0x67e5CF7C368C0a4A81b714dF57B2c6143D4C16A2;
    // A real collection with an open V3 MANA primary listing for item 0 on the fork block.
    address constant COLLECTION = 0xD5A806d332B45d62adF4d7d6E1b5DEf073f69768;
    uint256 constant ITEM_ID = 0;

    bytes32 constant EIP712_DOMAIN_TYPE_HASH = 0x36c25de3e541d5d970f66e4210d728721220fff5c077cc6cd008b3a0c62adab7;

    uint256 constant MANA_PRICE = 10 ether; // 10 MANA, ERC20-priced
    uint256 constant USD_PRICE = 1 ether; // $1.00, USD-pegged
    uint256 constant DISCOUNT_PPM = 300_000; // 30% off

    CreditsManagerPolygon creditsManager;
    V3TradeHashing tradeHashing;
    V3CouponHashing couponHashing;

    address creator;
    uint256 creatorPk;
    address creditsSigner;
    uint256 creditsSignerPk;
    address buyer;

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setUp() public {
        vm.createSelectFork("https://rpc.decentraland.org/polygon", FORK_BLOCK);

        creditsManager = CreditsManagerPolygon(CREDITS_MANAGER);
        tradeHashing = new V3TradeHashing();
        couponHashing = new V3CouponHashing();

        (creator, creatorPk) = makeAddrAndKey("creator");
        (creditsSigner, creditsSignerPk) = makeAddrAndKey("creditsSigner");
        buyer = address(this);

        bytes32 signerRole = creditsManager.CREDITS_SIGNER_ROLE();
        vm.prank(CREDITS_MANAGER_ADMIN);
        creditsManager.grantRole(signerRole, creditsSigner);

        vm.mockCall(COLLECTION, abi.encodeWithSignature("creator()"), abi.encode(creator));

        if (IERC20(MANA).balanceOf(CREDITS_MANAGER) < 100 ether) {
            deal(MANA, CREDITS_MANAGER, 100 ether);
        }

        assertEq(IV3SignatureIndexes(MARKETPLACE_V3).couponManager(), COUPON_MANAGER_V3, "V3 is wired to another CouponManager");
        assertTrue(creditsManager.marketplaces(MARKETPLACE_V3), "V3 must be an allowed marketplace");
        assertTrue(creditsManager.primarySalesAllowed(), "primary sales must be allowed");
    }

    function _checks(bytes32 _salt, uint256 _contractIndex, uint256 _signerIndex) internal view returns (CommonTypes.Checks memory) {
        return CommonTypes.Checks({
            uses: 1,
            expiration: block.timestamp + 1 days,
            effective: 0,
            salt: _salt,
            contractSignatureIndex: _contractIndex,
            signerSignatureIndex: _signerIndex,
            allowedRoot: bytes32(0),
            allowedProof: new bytes32[](0),
            externalChecks: new CommonTypes.ExternalCheck[](0)
        });
    }

    /// A primary listing of ITEM_ID signed by the creator against marketplace V3, priced in `_assetType`.
    function _signedListing(bytes32 _salt, uint256 _assetType, uint256 _price) internal view returns (MarketplaceTypes.Trade memory trade) {
        IV3SignatureIndexes market = IV3SignatureIndexes(MARKETPLACE_V3);

        trade.signer = creator;
        trade.checks = _checks(_salt, market.contractSignatureIndex(), market.signerSignatureIndex(creator));

        trade.sent = new MarketplaceTypes.Asset[](1);
        trade.sent[0] = MarketplaceTypes.Asset({
            assetType: creditsManager.ASSET_TYPE_COLLECTION_ITEM(), contractAddress: COLLECTION, value: ITEM_ID, beneficiary: buyer, extra: ""
        });

        trade.received = new MarketplaceTypes.Asset[](1);
        trade.received[0] = MarketplaceTypes.Asset({assetType: _assetType, contractAddress: MANA, value: _price, beneficiary: creator, extra: ""});

        bytes32 domain = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPE_HASH, keccak256(bytes("DecentralandMarketplacePolygon")), keccak256(bytes("1.0.0")), MARKETPLACE_V3, block.chainid
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPk, MessageHashUtils.toTypedDataHash(domain, tradeHashing.hashTrade(trade)));
        trade.signature = abi.encodePacked(r, s, v);
    }

    function _signedCoupon(bytes32 _salt) internal view returns (CouponTypes.Coupon memory coupon) {
        return _signedCoupon(_salt, 10);
    }

    function _signedCoupon(bytes32 _salt, uint256 _uses) internal view returns (CouponTypes.Coupon memory coupon) {
        IV3SignatureIndexes manager = IV3SignatureIndexes(COUPON_MANAGER_V3);
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(COLLECTION))));

        coupon.checks = _checks(_salt, manager.contractSignatureIndex(), manager.signerSignatureIndex(creator));
        coupon.checks.uses = _uses;
        coupon.couponAddress = COLLECTION_DISCOUNT_COUPON;
        coupon.data = abi.encode(CollectionDiscountCoupon.CollectionDiscountCouponData({discountType: 1, discount: DISCOUNT_PPM, root: leaf}));
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](0);
        coupon.callerData = abi.encode(CollectionDiscountCoupon.CollectionDiscountCouponCallerData({proofs: proofs}));

        bytes32 domain = keccak256(
            abi.encode(EIP712_DOMAIN_TYPE_HASH, keccak256(bytes("CouponManager")), keccak256(bytes("1.0.0")), COUPON_MANAGER_V3, block.chainid)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPk, MessageHashUtils.toTypedDataHash(domain, couponHashing.hashCoupon(coupon)));
        coupon.signature = abi.encodePacked(r, s, v);
    }

    function _useCreditsArgs(bytes4 _selector, bytes memory _data, uint256 _manaCap, bytes32 _creditSalt)
        internal
        view
        returns (CreditsManagerPolygon.UseCreditsArgs memory args, bytes32 creditHash)
    {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);
        credits[0] = CreditsManagerPolygon.Credit({value: _manaCap, expiresAt: block.timestamp + 1 hours, salt: _creditSalt});
        creditHash = keccak256(abi.encode(buyer, block.chainid, CREDITS_MANAGER, credits[0]));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditsSignerPk, creditHash.toEthSignedMessageHash());
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = abi.encodePacked(r, s, v);

        args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: signatures,
            externalCall: CreditsManagerPolygon.ExternalCall({
                target: MARKETPLACE_V3, selector: _selector, data: _data, expiresAt: 0, salt: bytes32(0)
            }),
            customExternalCallSignature: "",
            maxUncreditedValue: 0,
            maxCreditedValue: _manaCap
        });
    }

    function _one(MarketplaceTypes.Trade memory _trade) internal pure returns (MarketplaceTypes.Trade[] memory trades) {
        trades = new MarketplaceTypes.Trade[](1);
        trades[0] = _trade;
    }

    function _one(CouponTypes.Coupon memory _coupon) internal pure returns (CouponTypes.Coupon[] memory coupons) {
        coupons = new CouponTypes.Coupon[](1);
        coupons[0] = _coupon;
    }

    /// The MANA a credits purchase moved out of the manager, the credit it consumed and the creator payout.
    function _buyWithCredits(bytes4 _selector, bytes memory _data, uint256 _cap, bytes32 _salt)
        internal
        returns (uint256 manaOut, uint256 creditSpent, uint256 creatorIn)
    {
        (CreditsManagerPolygon.UseCreditsArgs memory args, bytes32 creditHash) = _useCreditsArgs(_selector, _data, _cap, _salt);
        uint256 managerBefore = IERC20(MANA).balanceOf(CREDITS_MANAGER);
        uint256 creatorBefore = IERC20(MANA).balanceOf(creator);
        creditsManager.useCredits(args);
        manaOut = managerBefore - IERC20(MANA).balanceOf(CREDITS_MANAGER);
        creditSpent = creditsManager.spentValue(creditHash);
        creatorIn = IERC20(MANA).balanceOf(creator) - creatorBefore;
    }

    // ---------------------------------------------------------------------------------------------------------

    /// The Shop's credits rail on a MANA-priced listing: the coupon must cut exactly 30% of the MANA price.
    function test_fork_v3_manaListing_creditsWithCoupon_chargesSeventyPercent() public {
        uint256 ownedBefore = IERC721(COLLECTION).balanceOf(buyer);
        uint256 expected = MANA_PRICE * (1_000_000 - DISCOUNT_PPM) / 1_000_000;

        CouponTypes.Coupon memory coupon = _signedCoupon(keccak256("coupon-mana-credits"));
        // Capped at the discounted price: a coupon that did not apply would ask for 10 MANA and revert.
        (uint256 manaOut, uint256 creditSpent, uint256 creatorIn) = _buyWithCredits(
            IMarketplace.acceptWithCoupon.selector,
            abi.encode(_one(_signedListing(keccak256("mana-credits"), creditsManager.ASSET_TYPE_ERC20(), MANA_PRICE)), _one(coupon)),
            expected,
            keccak256("credit-mana")
        );

        assertEq(IERC721(COLLECTION).balanceOf(buyer), ownedBefore + 1, "buyer did not receive the minted item");
        assertEq(manaOut, expected, "MANA out is not 70% of the MANA price");
        assertEq(creditSpent, manaOut, "credit consumed != MANA transferred");
        assertEq(creatorIn, manaOut * 975 / 1000, "creator payout is not the sale price less the 2.5% fee");
        emit log_named_decimal_uint("MANA listing price", MANA_PRICE, 18);
        emit log_named_decimal_uint("MANA paid with 30% coupon", manaOut, 18);
        emit log_named_decimal_uint("creator received", creatorIn, 18);
    }

    /// Control for the test above: the same MANA listing through plain `accept` moves the full price.
    function test_fork_v3_manaListing_creditsWithoutCoupon_chargesFullPrice() public {
        (uint256 manaOut,,) = _buyWithCredits(
            IMarketplace.accept.selector,
            abi.encode(_one(_signedListing(keccak256("mana-full"), creditsManager.ASSET_TYPE_ERC20(), MANA_PRICE))),
            MANA_PRICE,
            keccak256("credit-mana-full")
        );
        assertEq(manaOut, MANA_PRICE, "full-price control did not move the MANA price");
    }

    /// A buyer paying MANA from their own wallet, as the marketplace site does, gets the same 30% off.
    function test_fork_v3_manaListing_walletWithCoupon_chargesSeventyPercent() public {
        uint256 expected = MANA_PRICE * (1_000_000 - DISCOUNT_PPM) / 1_000_000;
        deal(MANA, buyer, 100 ether);
        IERC20(MANA).approve(MARKETPLACE_V3, type(uint256).max);

        uint256 buyerBefore = IERC20(MANA).balanceOf(buyer);
        uint256 creatorBefore = IERC20(MANA).balanceOf(creator);
        uint256 ownedBefore = IERC721(COLLECTION).balanceOf(buyer);

        IMarketplaceAcceptWithCoupon(MARKETPLACE_V3)
            .acceptWithCoupon(
                _one(_signedListing(keccak256("mana-wallet"), creditsManager.ASSET_TYPE_ERC20(), MANA_PRICE)),
                _one(_signedCoupon(keccak256("coupon-mana-wallet")))
            );

        assertEq(IERC721(COLLECTION).balanceOf(buyer), ownedBefore + 1, "buyer did not receive the minted item");
        assertEq(buyerBefore - IERC20(MANA).balanceOf(buyer), expected, "buyer did not pay 70% of the MANA price");
        assertEq(IERC20(MANA).balanceOf(creator) - creatorBefore, expected * 975 / 1000, "creator payout");
    }

    /// A one-use coupon must refuse a second unit: this is what caps a sale to N units.
    function test_fork_v3_oneUseCoupon_refusesTheSecondUnit() public {
        CouponTypes.Coupon memory coupon = _signedCoupon(keccak256("coupon-one-use"), 1);
        _buyWithCredits(
            IMarketplace.acceptWithCoupon.selector,
            abi.encode(_one(_signedListing(keccak256("unit-1"), creditsManager.ASSET_TYPE_USD_PEGGED_MANA(), USD_PRICE)), _one(coupon)),
            100 ether,
            keccak256("credit-unit-1")
        );

        (CreditsManagerPolygon.UseCreditsArgs memory args,) = _useCreditsArgs(
            IMarketplace.acceptWithCoupon.selector,
            abi.encode(_one(_signedListing(keccak256("unit-2"), creditsManager.ASSET_TYPE_USD_PEGGED_MANA(), USD_PRICE)), _one(coupon)),
            100 ether,
            keccak256("credit-unit-2")
        );
        // The CouponManager refuses it with SignatureOveruse inside the external call.
        vm.expectRevert();
        creditsManager.useCredits(args);
    }

    /// The Credits listing on V3, the case the Shop runs today, still settles at 70% through credits.
    function test_fork_v3_usdPeggedListing_creditsWithCoupon_chargesSeventyPercent() public {
        (uint256 fullMana,,) = _buyWithCredits(
            IMarketplace.accept.selector,
            abi.encode(_one(_signedListing(keccak256("usd-full"), creditsManager.ASSET_TYPE_USD_PEGGED_MANA(), USD_PRICE))),
            100 ether,
            keccak256("credit-usd-full")
        );
        uint256 expected = fullMana * (1_000_000 - DISCOUNT_PPM) / 1_000_000;

        (uint256 manaOut, uint256 creditSpent,) = _buyWithCredits(
            IMarketplace.acceptWithCoupon.selector,
            abi.encode(
                _one(_signedListing(keccak256("usd-sale"), creditsManager.ASSET_TYPE_USD_PEGGED_MANA(), USD_PRICE)),
                _one(_signedCoupon(keccak256("coupon-usd")))
            ),
            expected + 1e12,
            keccak256("credit-usd-sale")
        );

        assertApproxEqAbs(manaOut, expected, 1, "MANA out is not 70% of the full price");
        assertEq(creditSpent, manaOut, "credit consumed != MANA transferred");
    }
}
