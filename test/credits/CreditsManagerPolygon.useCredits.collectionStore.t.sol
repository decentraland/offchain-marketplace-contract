// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {CreditsManagerPolygon} from "src/credits/CreditsManagerPolygon.sol";
import {CreditsManagerPolygonTestBase} from "test/credits/utils/CreditsManagerPolygonTestBase.sol";
import {ICollectionStore} from "src/credits/interfaces/ICollectionStore.sol";

contract CreditsManagerPolygonUseCreditsCollectionStoreTest is CreditsManagerPolygonTestBase {
    function test_useCredits_Success() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 369 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        ICollectionStore.ItemToBuy[] memory itemsToBuy = new ICollectionStore.ItemToBuy[](1);

        itemsToBuy[0] = ICollectionStore.ItemToBuy({
            collection: collection,
            ids: new uint256[](1),
            prices: new uint256[](1),
            beneficiaries: new address[](1)
        });

        itemsToBuy[0].ids[0] = collectionItemId;
        itemsToBuy[0].prices[0] = 369 ether;
        itemsToBuy[0].beneficiaries[0] = address(this);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: collectionStore,
            selector: ICollectionStore.buy.selector,
            data: abi.encode(itemsToBuy),
            expiresAt: 0,
            salt: bytes32(0)
        });

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: bytes(""),
            maxUncreditedValue: 0,
            maxCreditedValue: 369 ether
        });

        // Transfer MANA to the credits manager.
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 369 ether);

        // Increase the max mana credited per hour to 369 ether.
        vm.prank(owner);
        creditsManager.updateMaxManaCreditedPerHour(369 ether);

        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));
        uint256 sellerBalanceBefore = IERC20(mana).balanceOf(collectionCreator);
        uint256 buyerBalanceBefore = IERC20(mana).balanceOf(address(this));
        uint256 buyerAssetBalanceBefore = IERC721(collection).balanceOf(address(this));

        creditsManager.useCredits(args);

        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 369 ether);
        assertEq(IERC20(mana).balanceOf(collectionCreator), sellerBalanceBefore + 369 ether - 9.225 ether); // With fees considered.
        assertEq(IERC20(mana).balanceOf(address(this)), buyerBalanceBefore);
        assertEq(IERC721(collection).balanceOf(address(this)), buyerAssetBalanceBefore + 1);
    }
}
