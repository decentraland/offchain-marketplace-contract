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

/// Exposes the EIP-712 struct hashes the contracts compute internally.
contract TradeHashing is MarketplaceTypesHashing {
    function hashTrade(Trade calldata _trade) external pure returns (bytes32) {
        return _hashTrade(_trade);
    }
}

contract CouponHashing is CouponTypesHashing {
    function hashCoupon(Coupon calldata _coupon) external pure returns (bytes32) {
        return _hashCoupon(_coupon);
    }
}

interface ISignatureIndexes {
    function contractSignatureIndex() external view returns (uint256);
    function signerSignatureIndex(address) external view returns (uint256);
    function signatureUses(bytes32) external view returns (uint256);
}

/// Proof for the Shop discounts plan (design/DISCOUNTS_PLAN.md, Phase 0): a credits purchase settled through
/// `acceptWithCoupon` on the PRODUCTION contracts, forked from Polygon mainnet.
///
/// Everything here is the real deployed bytecode: CreditsManager 0x8b3a…, marketplace V2 0xa40b…, the
/// CouponManager wired into it and the CollectionDiscountCoupon it allows, MANA and a real collection that is
/// listed in the Shop today. The only things faked are the keys (a test creator, a test credits signer granted
/// the role by the manager's admin) and the collection's `creator()`, which is mocked to the test creator so the
/// coupon can be signed by "the creator".
contract CreditsManagerPolygonUseCreditsAcceptWithCouponForkTest is Test, IERC721Receiver {
    using MessageHashUtils for bytes32;

    // Polygon mainnet
    uint256 constant FORK_BLOCK = 93_600_000;
    address constant MANA = 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4;
    address constant MARKETPLACE_V2 = 0xA40b1d129B8906888720686F3a01921dDF37716F;
    address constant COUPON_MANAGER = 0x3Fd3056EE72a2a85e9392FAB3A450E7736536081;
    address constant COLLECTION_DISCOUNT_COUPON = 0xc914507fE297b2dddd1232Ac3A8903F1c125e794;
    address constant CREDITS_MANAGER = 0x8B3A40CA1b6F5CaFC99d112a4d02E897d1FD8Cc5;
    address constant CREDITS_MANAGER_ADMIN = 0x67e5CF7C368C0a4A81b714dF57B2c6143D4C16A2;
    // "Reverence", item 0: listed in the Shop for 1 credit, 100k supply, marketplace V2 is a global minter.
    address constant COLLECTION = 0x4C09495CD2D4e3D3fA2808EB655d013DE426157b;
    uint256 constant ITEM_ID = 0;
    address constant OTHER_COLLECTION = 0xB0D0D31910Da4a14D4E05A9D51b6e9A99A85D676;

    bytes32 constant EIP712_DOMAIN_TYPE_HASH = 0x36c25de3e541d5d970f66e4210d728721220fff5c077cc6cd008b3a0c62adab7;

    uint256 constant FULL_PRICE_USD = 1 ether; // $1.00, USD-pegged
    uint256 constant DISCOUNT_PPM = 300_000; // 30% off

    CreditsManagerPolygon creditsManager;
    TradeHashing tradeHashing;
    CouponHashing couponHashing;

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
        tradeHashing = new TradeHashing();
        couponHashing = new CouponHashing();

        (creator, creatorPk) = makeAddrAndKey("creator");
        (creditsSigner, creditsSignerPk) = makeAddrAndKey("creditsSigner");
        buyer = address(this);

        // The production admin lets a test key sign credits, exactly the role the credits-server holds.
        // Read the role BEFORE pranking: a prank applies to the next external call, and the getter is one.
        bytes32 signerRole = creditsManager.CREDITS_SIGNER_ROLE();
        assertTrue(creditsManager.hasRole(bytes32(0), CREDITS_MANAGER_ADMIN), "admin address no longer holds DEFAULT_ADMIN_ROLE");
        vm.prank(CREDITS_MANAGER_ADMIN);
        creditsManager.grantRole(signerRole, creditsSigner);

        // Make the test key "the creator" of the collection, for both the marketplace and the coupon check.
        vm.mockCall(COLLECTION, abi.encodeWithSignature("creator()"), abi.encode(creator));

        // The manager holds the treasury float on mainnet; top it up only if the fork block caught it low.
        if (IERC20(MANA).balanceOf(CREDITS_MANAGER) < 100 ether) {
            deal(MANA, CREDITS_MANAGER, 100 ether);
        }

        assertTrue(creditsManager.marketplaces(MARKETPLACE_V2), "V2 must be an allowed marketplace");
        assertTrue(creditsManager.primarySalesAllowed(), "primary sales must be allowed");
    }

    // ---------------------------------------------------------------------------------------------------------
    // builders
    // ---------------------------------------------------------------------------------------------------------

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

    /// A primary (mint) listing of ITEM_ID at FULL_PRICE_USD, signed by the creator against marketplace V2.
    function _signedListing(bytes32 _salt) internal view returns (MarketplaceTypes.Trade memory trade) {
        ISignatureIndexes market = ISignatureIndexes(MARKETPLACE_V2);

        trade.signer = creator;
        trade.checks = _checks(_salt, market.contractSignatureIndex(), market.signerSignatureIndex(creator));

        trade.sent = new MarketplaceTypes.Asset[](1);
        trade.sent[0] = MarketplaceTypes.Asset({
            assetType: creditsManager.ASSET_TYPE_COLLECTION_ITEM(),
            contractAddress: COLLECTION,
            value: ITEM_ID,
            beneficiary: buyer,
            extra: ""
        });

        trade.received = new MarketplaceTypes.Asset[](1);
        trade.received[0] = MarketplaceTypes.Asset({
            assetType: creditsManager.ASSET_TYPE_USD_PEGGED_MANA(),
            contractAddress: MANA,
            value: FULL_PRICE_USD,
            beneficiary: creator,
            extra: ""
        });

        bytes32 domain = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPE_HASH,
                keccak256(bytes("DecentralandMarketplacePolygon")),
                keccak256(bytes("1.0.0")),
                MARKETPLACE_V2,
                block.chainid
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPk, MessageHashUtils.toTypedDataHash(domain, tradeHashing.hashTrade(trade)));
        trade.signature = abi.encodePacked(r, s, v);
    }

    /// A collection-wide percentage coupon signed by the creator against the production CouponManager.
    function _signedCoupon(address _collection, uint256 _discountPpm, uint256 _uses) internal view returns (CouponTypes.Coupon memory coupon) {
        ISignatureIndexes manager = ISignatureIndexes(COUPON_MANAGER);

        // A one-collection tree: the root IS the leaf, and the proof is empty.
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_collection))));

        coupon.checks = _checks(keccak256("coupon"), manager.contractSignatureIndex(), manager.signerSignatureIndex(creator));
        coupon.checks.uses = _uses;
        coupon.couponAddress = COLLECTION_DISCOUNT_COUPON;
        coupon.data = abi.encode(
            CollectionDiscountCoupon.CollectionDiscountCouponData({discountType: 1, discount: _discountPpm, root: leaf})
        );
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](0);
        coupon.callerData = abi.encode(CollectionDiscountCoupon.CollectionDiscountCouponCallerData({proofs: proofs}));

        bytes32 domain = keccak256(
            abi.encode(EIP712_DOMAIN_TYPE_HASH, keccak256(bytes("CouponManager")), keccak256(bytes("1.0.0")), COUPON_MANAGER, block.chainid)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPk, MessageHashUtils.toTypedDataHash(domain, couponHashing.hashCoupon(coupon)));
        coupon.signature = abi.encodePacked(r, s, v);
    }

    /// An ephemeral credit for this buyer, sized to `_manaCap`, signed by the (test) credits signer.
    function _signedCredit(uint256 _manaCap, bytes32 _salt)
        internal
        view
        returns (CreditsManagerPolygon.Credit[] memory credits, bytes[] memory signatures, bytes32 creditHash)
    {
        credits = new CreditsManagerPolygon.Credit[](1);
        credits[0] = CreditsManagerPolygon.Credit({value: _manaCap, expiresAt: block.timestamp + 1 hours, salt: _salt});
        creditHash = keccak256(abi.encode(buyer, block.chainid, CREDITS_MANAGER, credits[0]));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditsSignerPk, creditHash.toEthSignedMessageHash());
        signatures = new bytes[](1);
        signatures[0] = abi.encodePacked(r, s, v);
    }

    function _useCreditsArgs(bytes4 _selector, bytes memory _data, uint256 _manaCap, bytes32 _creditSalt)
        internal
        view
        returns (CreditsManagerPolygon.UseCreditsArgs memory args, bytes32 creditHash)
    {
        (CreditsManagerPolygon.Credit[] memory credits, bytes[] memory signatures, bytes32 hash) = _signedCredit(_manaCap, _creditSalt);
        creditHash = hash;
        args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: signatures,
            externalCall: CreditsManagerPolygon.ExternalCall({target: MARKETPLACE_V2, selector: _selector, data: _data, expiresAt: 0, salt: bytes32(0)}),
            customExternalCallSignature: "",
            maxUncreditedValue: 0,
            maxCreditedValue: _manaCap
        });
    }

    /// Control: the same listing bought at full price through plain `accept`. Returns the MANA that left the manager.
    function _buyAtFullPrice() internal returns (uint256 manaOut) {
        MarketplaceTypes.Trade[] memory trades = new MarketplaceTypes.Trade[](1);
        trades[0] = _signedListing(keccak256("full-price"));

        (CreditsManagerPolygon.UseCreditsArgs memory args,) =
            _useCreditsArgs(IMarketplace.accept.selector, abi.encode(trades), 100 ether, keccak256("credit-full"));

        uint256 before = IERC20(MANA).balanceOf(CREDITS_MANAGER);
        creditsManager.useCredits(args);
        manaOut = before - IERC20(MANA).balanceOf(CREDITS_MANAGER);
    }

    // ---------------------------------------------------------------------------------------------------------
    // tests
    // ---------------------------------------------------------------------------------------------------------

    function test_fork_acceptWithCoupon_chargesTheDiscountedPriceThroughCredits() public {
        uint256 fullMana = _buyAtFullPrice();
        assertGt(fullMana, 0, "control purchase moved no MANA");
        uint256 expectedSaleMana = fullMana * (1_000_000 - DISCOUNT_PPM) / 1_000_000;

        MarketplaceTypes.Trade[] memory trades = new MarketplaceTypes.Trade[](1);
        trades[0] = _signedListing(keccak256("sale"));
        CouponTypes.Coupon[] memory coupons = new CouponTypes.Coupon[](1);
        coupons[0] = _signedCoupon(COLLECTION, DISCOUNT_PPM, 10);

        // The cap is sized to the DISCOUNTED price plus a hair, the way the credits-server would size it. If the
        // coupon were not applied the marketplace would ask for the full price, exceed the approval, and revert.
        uint256 cap = expectedSaleMana + 1e12;
        (CreditsManagerPolygon.UseCreditsArgs memory args, bytes32 creditHash) =
            _useCreditsArgs(IMarketplace.acceptWithCoupon.selector, abi.encode(trades, coupons), cap, keccak256("credit-sale"));

        uint256 managerBefore = IERC20(MANA).balanceOf(CREDITS_MANAGER);
        uint256 creatorBefore = IERC20(MANA).balanceOf(creator);
        uint256 ownedBefore = IERC721(COLLECTION).balanceOf(buyer);
        // The deployed CouponManager scopes uses and cancellations by SIGNER: keccak256(abi.encode(signer, keccak256(sig))).
        bytes32 couponSigHash = keccak256(abi.encode(creator, keccak256(coupons[0].signature)));
        uint256 usesBefore = ISignatureIndexes(COUPON_MANAGER).signatureUses(couponSigHash);

        creditsManager.useCredits(args);

        uint256 saleMana = managerBefore - IERC20(MANA).balanceOf(CREDITS_MANAGER);

        // 1. the buyer got the item
        assertEq(IERC721(COLLECTION).balanceOf(buyer), ownedBefore + 1, "buyer did not receive the minted item");
        // 2. the manager paid exactly 70% of the full price (1 wei of rounding allowed)
        assertApproxEqAbs(saleMana, expectedSaleMana, 1, "MANA out is not 70% of the full price");
        // 3. the credit was consumed by the discounted amount, so the buyer's balance is debited the sale price
        assertEq(creditsManager.spentValue(creditHash), saleMana, "credit consumed != MANA transferred");
        // 4. the creator received the discounted amount minus the 2.5% marketplace fee
        assertApproxEqAbs(IERC20(MANA).balanceOf(creator) - creatorBefore, saleMana * 975 / 1000, 1, "creator payout");
        // 5. the CouponManager counted one use, so `uses` caps a sale in units
        assertEq(ISignatureIndexes(COUPON_MANAGER).signatureUses(couponSigHash), usesBefore + 1, "coupon use not counted");

        emit log_named_decimal_uint("MANA at full price ($1.00)", fullMana, 18);
        emit log_named_decimal_uint("MANA with 30% coupon       ", saleMana, 18);
        emit log_named_decimal_uint("creator received           ", IERC20(MANA).balanceOf(creator) - creatorBefore, 18);
    }

    function test_fork_acceptWithCoupon_revertsWhenTheCapIsBelowTheDiscountedPrice() public {
        uint256 fullMana = _buyAtFullPrice();
        uint256 expectedSaleMana = fullMana * (1_000_000 - DISCOUNT_PPM) / 1_000_000;

        MarketplaceTypes.Trade[] memory trades = new MarketplaceTypes.Trade[](1);
        trades[0] = _signedListing(keccak256("sale-undercap"));
        CouponTypes.Coupon[] memory coupons = new CouponTypes.Coupon[](1);
        coupons[0] = _signedCoupon(COLLECTION, DISCOUNT_PPM, 10);

        (CreditsManagerPolygon.UseCreditsArgs memory args,) = _useCreditsArgs(
            IMarketplace.acceptWithCoupon.selector, abi.encode(trades, coupons), expectedSaleMana - 1e15, keccak256("credit-undercap")
        );

        // A cap below what the discounted trade needs can never settle: the buyer cannot be over-charged past it.
        vm.expectRevert();
        creditsManager.useCredits(args);
    }

    function test_fork_acceptWithCoupon_revertsWhenTheCouponIsForAnotherCollection() public {
        MarketplaceTypes.Trade[] memory trades = new MarketplaceTypes.Trade[](1);
        trades[0] = _signedListing(keccak256("sale-foreign"));
        CouponTypes.Coupon[] memory coupons = new CouponTypes.Coupon[](1);
        coupons[0] = _signedCoupon(OTHER_COLLECTION, DISCOUNT_PPM, 10);

        (CreditsManagerPolygon.UseCreditsArgs memory args,) =
            _useCreditsArgs(IMarketplace.acceptWithCoupon.selector, abi.encode(trades, coupons), 100 ether, keccak256("credit-foreign"));

        vm.expectRevert();
        creditsManager.useCredits(args);
    }

    function test_fork_acceptWithCoupon_revertsWhenTheCouponUsesAreExhausted() public {
        MarketplaceTypes.Trade[] memory trades = new MarketplaceTypes.Trade[](1);
        trades[0] = _signedListing(keccak256("sale-cap-1"));
        CouponTypes.Coupon[] memory coupons = new CouponTypes.Coupon[](1);
        coupons[0] = _signedCoupon(COLLECTION, DISCOUNT_PPM, 1);

        (CreditsManagerPolygon.UseCreditsArgs memory args,) =
            _useCreditsArgs(IMarketplace.acceptWithCoupon.selector, abi.encode(trades, coupons), 100 ether, keccak256("credit-cap-1"));
        creditsManager.useCredits(args);

        // Second unit against a one-use coupon: the CouponManager refuses (SignatureOveruse inside the external call).
        trades[0] = _signedListing(keccak256("sale-cap-2"));
        (args,) = _useCreditsArgs(IMarketplace.acceptWithCoupon.selector, abi.encode(trades, coupons), 100 ether, keccak256("credit-cap-2"));
        vm.expectRevert();
        creditsManager.useCredits(args);
    }
}
