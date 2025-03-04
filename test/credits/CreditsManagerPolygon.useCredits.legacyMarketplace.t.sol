// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {CreditsManagerPolygon} from "src/credits/CreditsManagerPolygon.sol";
import {CreditsManagerPolygonTestBase} from "test/credits/utils/CreditsManagerPolygonTestBase.sol";
import {ILegacyMarketplace} from "src/credits/interfaces/ILegacyMarketplace.sol";

interface ITestLegacyMarketplace is ILegacyMarketplace {
    function createOrder(address _nftAddress, uint256 _assetId, uint256 _priceInWei, uint256 _expiresAt) external;
}

contract CreditsManagerPolygonUseCreditsLegacyMarketplaceTest is CreditsManagerPolygonTestBase, IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function test_useCredits_Success() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: legacyMarketplace,
            selector: ILegacyMarketplace.executeOrder.selector,
            data: abi.encode(collection, collectionTokenId, uint256(100 ether)),
            expiresAt: 0,
            salt: bytes32(0)
        });

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: bytes(""),
            maxUncreditedValue: 0,
            maxCreditedValue: 100 ether
        });

        // Set the legacy marketplace as approved for the collection.
        vm.prank(collectionTokenOwner);
        IERC721(collection).setApprovalForAll(legacyMarketplace, true);

        // Create an order on the legacy marketplace.
        vm.prank(collectionTokenOwner);
        ITestLegacyMarketplace(legacyMarketplace).createOrder(collection, collectionTokenId, 100 ether, type(uint256).max);

        // Transfer MANA to the credits manager.
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));
        uint256 sellerBalanceBefore = IERC20(mana).balanceOf(collectionTokenOwner);
        uint256 buyerBalanceBefore = IERC20(mana).balanceOf(address(this));

        assertEq(IERC721(collection).ownerOf(collectionTokenId), collectionTokenOwner);

        creditsManager.useCredits(args);

        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 100 ether);
        assertEq(IERC20(mana).balanceOf(collectionTokenOwner), sellerBalanceBefore + 100 ether);
        assertEq(IERC20(mana).balanceOf(address(this)), buyerBalanceBefore);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), address(this));
    }
}
