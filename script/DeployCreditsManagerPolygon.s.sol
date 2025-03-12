// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CreditsManagerPolygon} from "src/credits/CreditsManagerPolygon.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";

contract DeployCreditsManagerPolygonScript is Script {
    function run() public {
        // Get private key from environment
        uint256 pk = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(pk);
        
        // Create roles struct
        CreditsManagerPolygon.Roles memory roles = CreditsManagerPolygon.Roles({
            owner: vm.envAddress("OWNER"),
            signer: vm.envAddress("SIGNER"),
            pauser: vm.envAddress("PAUSER"),
            denier: vm.envAddress("DENIER"),
            revoker: vm.envAddress("REVOKER"),
            customExternalCallSigner: vm.envAddress("EXTERNAL_CALL_SIGNER"),
            customExternalCallRevoker: vm.envAddress("EXTERNAL_CALL_REVOKER")
        });
        
        // Deploy CreditsManagerPolygon contract
        CreditsManagerPolygon creditsManager = new CreditsManagerPolygon(
            roles,
            vm.envUint("MAX_MANA_CREDITED_PER_HOUR"),
            vm.envBool("PRIMARY_SALES_ALLOWED"),
            vm.envBool("SECONDARY_SALES_ALLOWED"),
            IERC20(vm.envAddress("MANA_TOKEN")),
            vm.envAddress("MARKETPLACE"),
            vm.envAddress("LEGACY_MARKETPLACE"),
            vm.envAddress("COLLECTION_STORE"),
            ICollectionFactory(vm.envAddress("COLLECTION_FACTORY")),
            ICollectionFactory(vm.envAddress("COLLECTION_FACTORY_V3"))
        );
        
        // Log the deployed contract address
        console.log("CreditsManagerPolygon deployed at:", address(creditsManager));
        
        vm.stopBroadcast();
    }
}
