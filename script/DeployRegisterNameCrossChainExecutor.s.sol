// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RegisterNameCrossChainExecutor} from "src/credits/executors/RegisterNameCrossChainExecutor.sol";

contract DeployRegisterNameCrossChainExecutorScript is Script {
    function run() public {
        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy RegisterNameCrossChainExecutor contract
        RegisterNameCrossChainExecutor executor = new RegisterNameCrossChainExecutor(
            vm.envAddress("EXECUTOR_OWNER"),
            vm.envAddress("CREDITS_MANAGER"),
            IERC20(vm.envAddress("MANA_TOKEN")),
            vm.envAddress("CORAL"),
            vm.envUint("MAX_USD_FEE"),
            vm.envAddress("MANA_USD_AGGREGATOR"),
            vm.envUint("MANA_USD_AGGREGATOR_TOLERANCE")
        );

        // Log the deployed contract address
        console.log("RegisterNameCrossChainExecutor deployed at:", address(executor));

        vm.stopBroadcast();
    }
}

