// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {CreditsManagerPolygon} from "src/credits/CreditsManagerPolygon.sol";
import {CreditsManagerPolygonTestBase} from "test/credits/utils/CreditsManagerPolygonTestBase.sol";
import {ILegacyMarketplace} from "src/credits/interfaces/ILegacyMarketplace.sol";

interface ITestLegacyMarketplace is ILegacyMarketplace {
    function createOrder(address _nftAddress, uint256 _assetId, uint256 _priceInWei, uint256 _expiresAt) external;
}

contract CreditsManagerPolygonUseCreditsLegacyMarketplaceTest is CreditsManagerPolygonTestBase {
    using MessageHashUtils for bytes32;

    function test_useCredits_RevertsWhenNotDecentralandNFTOrItem() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: legacyMarketplace,
            selector: ILegacyMarketplace.executeOrder.selector,
            data: abi.encode(address(0), collectionTokenId, uint256(100 ether)),
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

        vm.prank(collectionTokenOwner);
        IERC721(collection).setApprovalForAll(legacyMarketplace, true);

        vm.prank(collectionTokenOwner);
        ITestLegacyMarketplace(legacyMarketplace).createOrder(collection, collectionTokenId, 100 ether, type(uint256).max);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.NotDecentralandCollection.selector, address(0)));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenSecondarySalesAreNotAllowed() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

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

        vm.prank(collectionTokenOwner);
        IERC721(collection).setApprovalForAll(legacyMarketplace, true);

        vm.prank(collectionTokenOwner);
        ITestLegacyMarketplace(legacyMarketplace).createOrder(collection, collectionTokenId, 100 ether, type(uint256).max);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.prank(owner);
        creditsManager.updateSecondarySalesAllowed(false);

        vm.expectRevert(CreditsManagerPolygon.SecondarySalesNotAllowed.selector);
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenSelectorIsInvalid() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: legacyMarketplace,
            selector: bytes4(0),
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

        vm.prank(collectionTokenOwner);
        IERC721(collection).setApprovalForAll(legacyMarketplace, true);

        vm.prank(collectionTokenOwner);
        ITestLegacyMarketplace(legacyMarketplace).createOrder(collection, collectionTokenId, 100 ether, type(uint256).max);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.InvalidExternalCallSelector.selector, legacyMarketplace, bytes4(0)));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenTheCallerIsTheSameAsTheSeller() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(collectionTokenOwner, block.chainid, address(creditsManager), credits[0])));

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

        vm.prank(collectionTokenOwner);
        IERC721(collection).setApprovalForAll(legacyMarketplace, true);

        vm.prank(collectionTokenOwner);
        ITestLegacyMarketplace(legacyMarketplace).createOrder(collection, collectionTokenId, 100 ether, type(uint256).max);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.SenderBalanceChanged.selector));
        vm.prank(collectionTokenOwner);
        creditsManager.useCredits(args);
    }

    function test_useCredits_Success() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])).toEthSignedMessageHash()
        );

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

        vm.prank(collectionTokenOwner);
        IERC721(collection).setApprovalForAll(legacyMarketplace, true);

        vm.prank(collectionTokenOwner);
        ITestLegacyMarketplace(legacyMarketplace).createOrder(collection, collectionTokenId, 100 ether, type(uint256).max);

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
