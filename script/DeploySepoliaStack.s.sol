// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {EthereumStackDeployer} from "./DeployEthereumStack.s.sol";

/// @notice Sepolia TESTNET stack. Same steps as the Ethereum-family stack; only the values below differ.
/// The owner defaults to the deployer (msg.sender), so the CouponManager is wired automatically in the same
/// signing session — just fill the TODO addresses and sign.
contract DeploySepoliaStackScript is EthereumStackDeployer {
    function _config() internal view override returns (Config memory) {
        // Addresses are parsed from strings, so you can paste them in any casing (no EIP-55 checksum needed).
        return Config({
            owner: msg.sender, // deployer is the owner on testnet -> auto-wires updateCouponManager
            feeCollector: msg.sender,
            feeRate: 25000, // 2.5%
            mana: vm.parseAddress("0xfa04d2e2ba9aec166c93dfeeba7427b2303befa9"), // TODO: MANA on Sepolia
            manaEthAggregator: vm.parseAddress("0x8184125efb44e8a3950fce7c3ad5292f1d448968"), // TODO: MANA/ETH feed on Sepolia (or a mock)
            manaEthAggregatorTolerance: 86400,
            ethUsdAggregator: vm.parseAddress("0x0cf2901c01df53f868dcf6bb6680cfd9859ea3e1"), // TODO: ETH/USD feed on Sepolia
            ethUsdAggregatorTolerance: 3600
        });
    }
}
