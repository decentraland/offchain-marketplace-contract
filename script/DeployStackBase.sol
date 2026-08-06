// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";

/// @notice Shared helpers for the deploy stacks: a per-network block-explorer base and a
/// "  <name>: <address>" + explorer-link logger used in the final DEPLOYED CONTRACTS summary.
abstract contract DeployStackBase is Script {
    /// @dev Block-explorer "address" base URL for the current chain, or "" if unknown (e.g. local sim).
    function _explorerBase() internal view returns (string memory) {
        uint256 id = block.chainid;
        if (id == 1) return "https://etherscan.io/address/";
        if (id == 11155111) return "https://sepolia.etherscan.io/address/";
        if (id == 137) return "https://polygonscan.com/address/";
        if (id == 80002) return "https://amoy.polygonscan.com/address/";
        return "";
    }

    /// @dev Logs "  <name>: <address>" and, when the chain is known, the explorer #code link below it.
    function _logDeployed(string memory _name, address _addr) internal view {
        string memory addr = vm.toString(_addr);
        console.log(string.concat("  ", _name, ": ", addr));

        string memory base = _explorerBase();
        if (bytes(base).length != 0) {
            console.log(string.concat("    ", base, addr, "#code"));
        }
    }
}
