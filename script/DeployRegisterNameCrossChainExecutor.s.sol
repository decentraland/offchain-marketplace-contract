// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RegisterNameCrossChainExecutor} from "src/credits/executors/RegisterNameCrossChainExecutor.sol";
import {CreditsManagerPolygon} from "src/credits/CreditsManagerPolygon.sol";

/// @notice Deploys the RegisterNameCrossChainExecutor on POLYGON. Values are baked into `_config()`
/// below — no .env needed. Run without --broadcast first to review the pre-flight echo.
///
/// Dry-run (review parameters, no transactions):
///   forge script script/DeployRegisterNameCrossChainExecutor.s.sol --rpc-url https://rpc.decentraland.org/polygon
///
/// Deploy + verify on Polygonscan:
///   forge script script/DeployRegisterNameCrossChainExecutor.s.sol --rpc-url https://rpc.decentraland.org/polygon \
///     --broadcast --verify --etherscan-api-key $POLYGONSCAN_API_KEY {wallet flags, e.g. --ledger or --private-key}
///
/// If it was deployed without --verify (or verification failed), verify after the fact with:
///   forge verify-contract {deployedAddress} src/credits/executors/RegisterNameCrossChainExecutor.sol:RegisterNameCrossChainExecutor \
///     --chain polygon --etherscan-api-key $POLYGONSCAN_API_KEY --watch \
///     --constructor-args $(cast abi-encode "constructor(address,address,address,address,uint256,address,uint256)" \
///       {owner} {creditsManager} {mana} {executor} {maxUSDFee} {manaUsdAggregator} {manaUsdAggregatorTolerance})
contract DeployRegisterNameCrossChainExecutorScript is Script {
    struct Config {
        address owner;
        address creditsManager;
        address mana;
        address executor;
        uint256 maxUSDFee;
        address manaUsdAggregator;
        uint256 manaUsdAggregatorTolerance;
        bool allowInCreditsManager;
    }

    function _config() internal view returns (Config memory) {
        // Addresses are parsed from strings, so you can paste them in any casing (no EIP-55 checksum needed).
        return Config({
            owner: vm.parseAddress("0x67e5CF7C368C0a4A81b714dF57B2c6143D4C16A2"),
            creditsManager: vm.parseAddress("0x8b3a40ca1b6f5cafc99d112a4d02e897d1fd8cc5"),
            mana: vm.parseAddress("0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4"), // MANA on Polygon
            executor: vm.parseAddress("0x97CCDBea4632140639aD5eA9b944aa034eb15fD4"), // Executor cross-chain executor on Polygon
            maxUSDFee: 5 ether, // $5.00 max fee payable in MANA (18 decimals)
            manaUsdAggregator: vm.parseAddress("0xA1CbF3Fe43BC3501e3Fc4b573e822c70e76A7512"), // Chainlink MANA/USD feed on Polygon
            manaUsdAggregatorTolerance: 54, // seconds before the aggregator result is considered outdated
            allowInCreditsManager: true // allow the deployed executor as a custom external call on the CreditsManager
        });
    }

    function run() public {
        Config memory c = _config();

        CreditsManagerPolygon creditsManager = CreditsManagerPolygon(c.creditsManager);
        // The allow-list step is onlyRole(DEFAULT_ADMIN_ROLE) on the CreditsManager: it runs automatically when the
        // deployer holds that role; otherwise the exact governance call is logged at the end for the admin/multisig.
        bool deployerIsCreditsManagerAdmin = creditsManager.hasRole(creditsManager.DEFAULT_ADMIN_ROLE(), msg.sender);

        // Pre-flight: echo every parameter so it can be reviewed before signing (shown in the dry-run).
        console.log("==============================================================================");
        console.log("Are you sure you want to deploy RegisterNameCrossChainExecutor with these parameters?");
        console.log("  signer (deployer):", msg.sender);
        console.log("  owner:", c.owner);
        console.log("  creditsManager:", c.creditsManager);
        console.log("  mana:", c.mana);
        console.log("  executor:", c.executor);
        console.log(string.concat("  maxUSDFee (USD, 18 decimals): ", vm.toString(c.maxUSDFee)));
        console.log("  manaUsdAggregator:", c.manaUsdAggregator);
        console.log(string.concat("  manaUsdAggregatorTolerance (seconds): ", vm.toString(c.manaUsdAggregatorTolerance)));
        console.log(string.concat("  allow as custom external call on CreditsManager? ", vm.toString(c.allowInCreditsManager)));
        if (c.allowInCreditsManager) {
            console.log(string.concat("    auto-wire in this run (deployer is CreditsManager admin)? ", vm.toString(deployerIsCreditsManagerAdmin)));
        }
        console.log("If anything looks wrong, Ctrl-C now. Run without --broadcast first to review.");
        console.log("==============================================================================");

        vm.startBroadcast();

        RegisterNameCrossChainExecutor executor = new RegisterNameCrossChainExecutor(
            c.owner, c.creditsManager, IERC20(c.mana), c.executor, c.maxUSDFee, c.manaUsdAggregator, c.manaUsdAggregatorTolerance
        );

        if (c.allowInCreditsManager && deployerIsCreditsManagerAdmin) {
            creditsManager.allowCustomExternalCall(address(executor), RegisterNameCrossChainExecutor.execute.selector, true);
        }

        vm.stopBroadcast();

        console.log("RegisterNameCrossChainExecutor deployed at:", address(executor));
        console.log(string.concat("  https://polygonscan.com/address/", vm.toString(address(executor)), "#code"));

        if (c.allowInCreditsManager) {
            if (deployerIsCreditsManagerAdmin) {
                console.log("Executor allowed as custom external call on the CreditsManager (execute selector).");
            } else {
                console.log("Deployer is NOT the CreditsManager admin, so the allow-list step was skipped.");
                console.log("From the admin, call allowCustomExternalCall(executor, execute selector, true):");
                console.log(string.concat("  to (CreditsManager): ", vm.toString(c.creditsManager)));
                console.log(
                    string.concat(
                        "  calldata: ",
                        vm.toString(
                            abi.encodeCall(
                                CreditsManagerPolygon.allowCustomExternalCall,
                                (address(executor), RegisterNameCrossChainExecutor.execute.selector, true)
                            )
                        )
                    )
                );
            }
        }
    }
}
