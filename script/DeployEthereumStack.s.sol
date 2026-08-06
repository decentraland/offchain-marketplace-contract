// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {console} from "forge-std/Script.sol";
import {DeployStackBase} from "./DeployStackBase.sol";
import {DecentralandMarketplaceEthereum} from "src/marketplace/DecentralandMarketplaceEthereum.sol";
import {CouponManager} from "src/coupons/CouponManager.sol";

/// @notice Deploy logic shared by the Ethereum-family stacks (mainnet below, Sepolia in DeploySepoliaStack.s.sol).
/// Values are baked into each concrete `_config()` — no .env needed. Deploys in README#Deployment order:
///   1. DecentralandMarketplaceEthereum  (couponManager = address(0) at construction)
///   2. CouponManager                     (owner = config.owner, no allowed coupons — Ethereum has none today)
///   3. marketplace.updateCouponManager(couponManager)   [only when the deployer is the owner]
///
/// Step 3 is `onlyOwner`: on testnet the owner is the deployer EOA so it runs automatically ("just sign");
/// on mainnet the owner is the DAO multisig, so step 3 is skipped and the exact governance call is logged.
abstract contract EthereumStackDeployer is DeployStackBase {
    struct Config {
        address owner;
        address feeCollector;
        uint256 feeRate;
        address mana;
        address manaEthAggregator;
        uint256 manaEthAggregatorTolerance;
        address ethUsdAggregator;
        uint256 ethUsdAggregatorTolerance;
    }

    /// @dev Per-network values. Override in the concrete script.
    function _config() internal view virtual returns (Config memory);

    function run() public {
        Config memory c = _config();
        address deployer = msg.sender;

        // Pre-flight: echo every parameter so it can be reviewed before signing (shown in the dry-run).
        console.log("=========================================================================");
        console.log("Are you sure you want to deploy the ETHEREUM stack with these parameters?");
        console.log("  signer (deployer):", deployer);
        console.log("  owner:", c.owner);
        console.log("  feeCollector:", c.feeCollector);
        console.log("  feeRate (bps/1e6):", c.feeRate);
        console.log("  mana:", c.mana);
        console.log("  manaEthAggregator:", c.manaEthAggregator);
        console.log("  manaEthAggregatorTolerance:", c.manaEthAggregatorTolerance);
        console.log("  ethUsdAggregator:", c.ethUsdAggregator);
        console.log("  ethUsdAggregatorTolerance:", c.ethUsdAggregatorTolerance);
        console.log("  couponManager: deployed in this run, no allowed coupons (Ethereum has none)");
        console.log("  auto-wire updateCouponManager?", c.owner == deployer);
        console.log("If anything looks wrong, Ctrl-C now. Run without --broadcast first to review.");
        console.log("=========================================================================");

        vm.startBroadcast();

        // 1. Marketplace (no coupon manager yet; wired in step 3 / by governance).
        DecentralandMarketplaceEthereum marketplace = new DecentralandMarketplaceEthereum(
            c.owner,
            address(0),
            c.feeCollector,
            c.feeRate,
            c.mana,
            c.manaEthAggregator,
            c.manaEthAggregatorTolerance,
            c.ethUsdAggregator,
            c.ethUsdAggregatorTolerance
        );
        console.log("DecentralandMarketplaceEthereum deployed at:", address(marketplace));

        // 2. CouponManager with no allowed coupons (Ethereum has none today).
        CouponManager couponManager = new CouponManager(address(marketplace), c.owner, new address[](0));
        console.log("CouponManager deployed at:", address(couponManager));

        // 3. Wire the CouponManager into the marketplace if the deployer owns it (testnet); else log the call.
        if (c.owner == deployer) {
            marketplace.updateCouponManager(address(couponManager));
            console.log("Wired CouponManager into marketplace via updateCouponManager.");
        } else {
            console.log("Owner is a multisig, not the deployer -> governance must finish wiring:");
            console.log("  on marketplace:", address(marketplace));
            console.log("  call updateCouponManager(couponManager):", address(couponManager));
        }

        vm.stopBroadcast();

        // Final summary: every contract deployed by this run, in one place.
        console.log("=========================================================================");
        console.log("DEPLOYED CONTRACTS");
        _logDeployed("DecentralandMarketplaceEthereum", address(marketplace));
        _logDeployed("CouponManager", address(couponManager));
        console.log("=========================================================================");
    }
}

/// @notice Ethereum MAINNET stack. Public production values from README#Deployment — no config needed, just sign.
contract DeployEthereumStackScript is EthereumStackDeployer {
    function _config() internal pure override returns (Config memory) {
        return Config({
            owner: 0x9A6ebE7E2a7722F8200d0ffB63a1F6406A0d7dce, // DAO
            feeCollector: 0x9A6ebE7E2a7722F8200d0ffB63a1F6406A0d7dce, // DAO
            feeRate: 25000, // 2.5%
            mana: 0x0F5D2fB29fb7d3CFeE444a200298f468908cC942,
            manaEthAggregator: 0x82A44D92D6c329826dc557c5E1Be6ebeC5D5FeB9,
            manaEthAggregatorTolerance: 86400, // heartbeat
            ethUsdAggregator: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            ethUsdAggregatorTolerance: 3600 // heartbeat
        });
    }
}
