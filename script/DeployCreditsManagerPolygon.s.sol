// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CreditsManagerPolygon} from "src/credits/CreditsManagerPolygon.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";

contract DeployCreditsManagerPolygonScript is Script {
    function _createMarketplaceArray(address _marketplace) private pure returns (address[] memory) {
        address[] memory marketplaces = new address[](1);
        marketplaces[0] = _marketplace;
        return marketplaces;
    }

    function run() public {
        // Start broadcasting transactions
        vm.startBroadcast();

        // Create roles struct
        CreditsManagerPolygon.Roles memory roles = CreditsManagerPolygon.Roles({
            owner: vm.envAddress("OWNER"),
            creditsSigner: vm.envAddress("CREDITS_SIGNER"),
            pauser: vm.envAddress("PAUSER"),
            userDenier: vm.envAddress("USER_DENIER"),
            creditsRevoker: vm.envAddress("CREDITS_REVOKER"),
            customExternalCallSigner: vm.envAddress("CUSTOM_EXTERNAL_CALL_SIGNER"),
            customExternalCallRevoker: vm.envAddress("CUSTOM_EXTERNAL_CALL_REVOKER")
        });

        // Deploy CreditsManagerPolygon contract
        CreditsManagerPolygon creditsManager = new CreditsManagerPolygon(
            roles,
            vm.envUint("MAX_MANA_CREDITED_PER_HOUR"),
            vm.envBool("PRIMARY_SALES_ALLOWED"),
            vm.envBool("SECONDARY_SALES_ALLOWED"),
            IERC20(vm.envAddress("MANA_TOKEN")),
            vm.envAddress("LEGACY_MARKETPLACE"),
            vm.envAddress("COLLECTION_STORE"),
            ICollectionFactory(vm.envAddress("COLLECTION_FACTORY")),
            ICollectionFactory(vm.envAddress("COLLECTION_FACTORY_V3")),
            _createMarketplaceArray(vm.envAddress("MARKETPLACE"))
        );

        // Log the deployed contract address
        console.log("CreditsManagerPolygon deployed at:", address(creditsManager));

        vm.stopBroadcast();
    }
}
