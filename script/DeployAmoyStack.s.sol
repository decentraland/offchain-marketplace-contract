// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {PolygonStackDeployer} from "./DeployPolygonStack.s.sol";

/// @notice Amoy TESTNET stack. Same steps as the Polygon-family stack; only the values below differ.
/// The owner defaults to the deployer (msg.sender), so the CouponManager is wired automatically in the same
/// signing session — just fill the TODO addresses and sign.
contract DeployAmoyStackScript is PolygonStackDeployer {
    function _config() internal view override returns (Config memory) {
        // Addresses are parsed from strings, so you can paste them in any casing (no EIP-55 checksum needed).
        return Config({
            owner: msg.sender, // deployer is the owner on testnet -> auto-wires updateCouponManager
            feeCollector: msg.sender,
            feeRate: 25000, // 2.5%
            royaltiesManager: vm.parseAddress("0x0cff059845c6abee7de396d00091016ad72fd324"), // TODO: royalties manager on Amoy (or a mock)
            royaltiesRate: 25000, // 2.5%
            mana: vm.parseAddress("0x7ad72b9f944ea9793cf4055d88f81138cc2c63a0"), // TODO: MANA on Amoy
            manaUsdAggregator: vm.parseAddress("0xdcf00f5f60b62b07e668a84c0cedaf6f453d416e"), // TODO: MANA/USD feed on Amoy (or a mock)
            manaUsdAggregatorTolerance: 54 // 2x the 27s feed heartbeat, same as Polygon mainnet
        });
    }
}
