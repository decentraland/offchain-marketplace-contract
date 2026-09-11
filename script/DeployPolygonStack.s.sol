// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {console} from "forge-std/Script.sol";
import {DeployStackBase} from "./DeployStackBase.sol";
import {DecentralandMarketplacePolygon} from "src/marketplace/DecentralandMarketplacePolygon.sol";
import {CollectionDiscountCoupon} from "src/coupons/CollectionDiscountCoupon.sol";
import {CouponManager} from "src/coupons/CouponManager.sol";

/// @notice Deploy logic shared by the Polygon-family stacks (mainnet below, Amoy in DeployAmoyStack.s.sol).
/// Values are baked into each concrete `_config()` — no .env needed. Deploys in README#Deployment order:
///   1. DecentralandMarketplacePolygon   (owner = deployer, couponManager = address(0) at construction)
///   2. CollectionDiscountCoupon         (config.collectionDiscountCoupon if set, else a fresh deploy; it is stateless)
///   3. CouponManager                     (owner = config.owner, allowed coupons = [CollectionDiscountCoupon])
///   4. marketplace.updateCouponManager(couponManager)   [deployer is still the owner, so it always runs]
///   5. marketplace.transferOwnership(config.owner)      [only when config.owner differs from the deployer]
///
/// Deploying with the deployer as owner wires the whole stack in one signing session; the final owner
/// (SAB multisig on mainnet) receives ownership at the end and never has to run setup calls.
abstract contract PolygonStackDeployer is DeployStackBase {
    struct Config {
        address owner;
        address feeCollector;
        uint256 feeRate;
        address royaltiesManager;
        uint256 royaltiesRate;
        address mana;
        address manaUsdAggregator;
        uint256 manaUsdAggregatorTolerance;
        address collectionDiscountCoupon;
    }

    /// @dev Per-network values. Override in the concrete script.
    function _config() internal view virtual returns (Config memory);

    function run() public {
        Config memory c = _config();
        address deployer = msg.sender;

        // Pre-flight: echo every parameter so it can be reviewed before signing (shown in the dry-run).
        console.log("========================================================================");
        console.log("Are you sure you want to deploy the POLYGON stack with these parameters?");
        console.log("  signer (deployer):", deployer);
        console.log("  owner (final, after wiring):", c.owner);
        console.log("  feeCollector:", c.feeCollector);
        console.log("  feeRate (bps/1e6):", c.feeRate);
        console.log("  royaltiesManager:", c.royaltiesManager);
        console.log("  royaltiesRate (bps/1e6):", c.royaltiesRate);
        console.log("  mana:", c.mana);
        console.log("  manaUsdAggregator:", c.manaUsdAggregator);
        console.log("  manaUsdAggregatorTolerance:", c.manaUsdAggregatorTolerance);
        if (c.collectionDiscountCoupon == address(0)) {
            console.log("  allowed coupons: the CollectionDiscountCoupon deployed in this run");
        } else {
            console.log("  allowed coupons: existing CollectionDiscountCoupon", c.collectionDiscountCoupon);
        }
        console.log("  transfer ownership to owner after wiring?", c.owner != deployer);
        console.log("If anything looks wrong, Ctrl-C now. Run without --broadcast first to review.");
        console.log("========================================================================");

        vm.startBroadcast();

        // 1. Marketplace owned by the deployer for now (no coupon manager yet; wired in step 4).
        DecentralandMarketplacePolygon marketplace = new DecentralandMarketplacePolygon(
            deployer,
            address(0),
            c.feeCollector,
            c.feeRate,
            c.royaltiesManager,
            c.royaltiesRate,
            c.mana,
            c.manaUsdAggregator,
            c.manaUsdAggregatorTolerance
        );
        console.log("DecentralandMarketplacePolygon deployed at:", address(marketplace));

        // 2. CollectionDiscountCoupon (the only allowed coupon implementation today). Stateless, so a configured deployment is reused.
        address collectionDiscountCoupon = c.collectionDiscountCoupon;
        if (collectionDiscountCoupon == address(0)) {
            collectionDiscountCoupon = address(new CollectionDiscountCoupon());
            console.log("CollectionDiscountCoupon deployed at:", collectionDiscountCoupon);
        } else {
            require(collectionDiscountCoupon.code.length != 0, "collectionDiscountCoupon has no code");
            console.log("CollectionDiscountCoupon reused at:", collectionDiscountCoupon);
        }

        // 3. CouponManager allowing the CollectionDiscountCoupon.
        address[] memory allowedCoupons = new address[](1);
        allowedCoupons[0] = collectionDiscountCoupon;
        CouponManager couponManager = new CouponManager(address(marketplace), c.owner, allowedCoupons);
        console.log("CouponManager deployed at:", address(couponManager));

        // 4. Wire the CouponManager while the deployer is still the owner.
        marketplace.updateCouponManager(address(couponManager));
        console.log("Wired CouponManager into marketplace via updateCouponManager.");

        // 5. Hand the marketplace over to its final owner (SAB multisig on mainnet; no-op on testnet).
        if (c.owner != deployer) {
            require(c.owner.code.length != 0, "final owner has no code; refusing to transfer ownership");
            marketplace.transferOwnership(c.owner);
            console.log("Transferred marketplace ownership to:", c.owner);
        }

        vm.stopBroadcast();

        // Post-conditions: a failure here aborts the simulation, so nothing gets broadcast.
        require(marketplace.owner() == c.owner, "marketplace owner mismatch");
        require(address(marketplace.couponManager()) == address(couponManager), "couponManager not wired");
        require(couponManager.owner() == c.owner, "couponManager owner mismatch");

        // Final summary: every contract deployed by this run, in one place.
        console.log("=========================================================================");
        console.log("DEPLOYED CONTRACTS");
        _logDeployed("DecentralandMarketplacePolygon", address(marketplace));
        _logDeployed(
            c.collectionDiscountCoupon == address(0) ? "CollectionDiscountCoupon" : "CollectionDiscountCoupon (reused)", collectionDiscountCoupon
        );
        _logDeployed("CouponManager", address(couponManager));
        console.log("=========================================================================");
    }
}

/// @notice Polygon MAINNET stack. Public production values from README#Deployment — no config needed, just sign.
contract DeployPolygonStackScript is PolygonStackDeployer {
    function _config() internal pure override returns (Config memory) {
        return Config({
            owner: 0x0E659A116e161d8e502F9036bAbDA51334F2667E, // SAB
            feeCollector: 0x184e4D9A26Add0aF1eAfC145550E890a421f16d7, // DAO FEE COLLECTOR
            feeRate: 25000, // 2.5%
            royaltiesManager: 0x90958D4531258ca11D18396d4174a007edBc2b42,
            royaltiesRate: 25000, // 2.5%
            mana: 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4,
            manaUsdAggregator: 0xA1CbF3Fe43BC3501e3Fc4b573e822c70e76A7512,
            manaUsdAggregatorTolerance: 54, // 2x the 27s feed heartbeat, matches the deployed RegisterNameCrossChainExecutor
            collectionDiscountCoupon: 0xc914507fE297b2dddd1232Ac3A8903F1c125e794 // verified, same source as this build (paris target); the coupon allowed by the live CouponManager
        });
    }
}
