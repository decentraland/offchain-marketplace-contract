// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {CreditsManagerPolygon} from "src/credits/CreditsManagerPolygon.sol";
import {CreditsManagerPolygonTestBase} from "test/credits/utils/CreditsManagerPolygonTestBase.sol";
import {IMarketplace} from "src/credits/interfaces/IMarketplace.sol";

contract CreditsManagerPolygonUseCreditsMarketplaceTest is CreditsManagerPolygonTestBase {
    using MessageHashUtils for bytes32;

    function test_useCredits_RevertsWhenNotDecentralandItem() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])).toEthSignedMessageHash()
        );

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, seller, collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        IMarketplace.Trade memory trade = IMarketplace.Trade({
            signer: seller,
            signature: "",
            checks: IMarketplace.Checks({
                uses: 1,
                expiration: type(uint256).max,
                effective: 0,
                salt: bytes32(0),
                contractSignatureIndex: 0,
                signerSignatureIndex: 0,
                allowedRoot: bytes32(0),
                allowedProof: new bytes32[](0),
                externalChecks: new IMarketplace.ExternalCheck[](0)
            }),
            sent: new IMarketplace.Asset[](1),
            received: new IMarketplace.Asset[](1)
        });

        IMarketplace.Asset memory manaAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC20(),
            contractAddress: mana,
            value: 100 ether,
            beneficiary: address(0),
            extra: new bytes(0)
        });

        trade.received[0] = manaAsset;

        IMarketplace.Asset memory nftAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC721(),
            contractAddress: address(0),
            value: collectionTokenId,
            beneficiary: address(this),
            extra: new bytes(0)
        });

        trade.sent[0] = nftAsset;

        (v, r, s) = vm.sign(sellerPk, creditsManager.tradeToTypedHashData(trade, marketplace));

        trade.signature = abi.encodePacked(r, s, v);

        IMarketplace.Trade[] memory trades = new IMarketplace.Trade[](1);
        trades[0] = trade;

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: marketplace,
            selector: IMarketplace.accept.selector,
            data: abi.encode(trades),
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

        vm.prank(seller);
        IERC721(collection).setApprovalForAll(marketplace, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.NotDecentralandCollection.selector, address(0)));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenTheSentBeneficiaryIsZero() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, seller, collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        IMarketplace.Trade memory trade = IMarketplace.Trade({
            signer: seller,
            signature: "",
            checks: IMarketplace.Checks({
                uses: 1,
                expiration: type(uint256).max,
                effective: 0,
                salt: bytes32(0),
                contractSignatureIndex: 0,
                signerSignatureIndex: 0,
                allowedRoot: bytes32(0),
                allowedProof: new bytes32[](0),
                externalChecks: new IMarketplace.ExternalCheck[](0)
            }),
            sent: new IMarketplace.Asset[](1),
            received: new IMarketplace.Asset[](1)
        });

        IMarketplace.Asset memory manaAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC20(),
            contractAddress: mana,
            value: 100 ether,
            beneficiary: address(0),
            extra: new bytes(0)
        });

        trade.received[0] = manaAsset;

        IMarketplace.Asset memory nftAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC721(),
            contractAddress: collection,
            value: collectionTokenId,
            beneficiary: address(0),
            extra: new bytes(0)
        });

        trade.sent[0] = nftAsset;

        (v, r, s) = vm.sign(sellerPk, creditsManager.tradeToTypedHashData(trade, marketplace));

        trade.signature = abi.encodePacked(r, s, v);

        IMarketplace.Trade[] memory trades = new IMarketplace.Trade[](1);
        trades[0] = trade;

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: marketplace,
            selector: IMarketplace.accept.selector,
            data: abi.encode(trades),
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

        vm.prank(seller);
        IERC721(collection).setApprovalForAll(marketplace, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.expectRevert(CreditsManagerPolygon.InvalidBeneficiary.selector);
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenAssetIsCollectionItemAndPrimarySalesAreNotAllowed() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, seller, collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        IMarketplace.Trade memory trade = IMarketplace.Trade({
            signer: seller,
            signature: "",
            checks: IMarketplace.Checks({
                uses: 1,
                expiration: type(uint256).max,
                effective: 0,
                salt: bytes32(0),
                contractSignatureIndex: 0,
                signerSignatureIndex: 0,
                allowedRoot: bytes32(0),
                allowedProof: new bytes32[](0),
                externalChecks: new IMarketplace.ExternalCheck[](0)
            }),
            sent: new IMarketplace.Asset[](1),
            received: new IMarketplace.Asset[](1)
        });

        IMarketplace.Asset memory manaAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC20(),
            contractAddress: mana,
            value: 100 ether,
            beneficiary: address(0),
            extra: new bytes(0)
        });

        trade.received[0] = manaAsset;

        IMarketplace.Asset memory nftAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_COLLECTION_ITEM(),
            contractAddress: collection,
            value: collectionItemId,
            beneficiary: address(this),
            extra: new bytes(0)
        });

        trade.sent[0] = nftAsset;

        (v, r, s) = vm.sign(sellerPk, creditsManager.tradeToTypedHashData(trade, marketplace));

        trade.signature = abi.encodePacked(r, s, v);

        IMarketplace.Trade[] memory trades = new IMarketplace.Trade[](1);
        trades[0] = trade;

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: marketplace,
            selector: IMarketplace.accept.selector,
            data: abi.encode(trades),
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

        vm.prank(seller);
        IERC721(collection).setApprovalForAll(marketplace, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.prank(owner);
        creditsManager.updatePrimarySalesAllowed(false);

        vm.expectRevert(CreditsManagerPolygon.PrimarySalesNotAllowed.selector);
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenAssetIsERC721AndSecondarySalesAreNotAllowed() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, seller, collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        IMarketplace.Trade memory trade = IMarketplace.Trade({
            signer: seller,
            signature: "",
            checks: IMarketplace.Checks({
                uses: 1,
                expiration: type(uint256).max,
                effective: 0,
                salt: bytes32(0),
                contractSignatureIndex: 0,
                signerSignatureIndex: 0,
                allowedRoot: bytes32(0),
                allowedProof: new bytes32[](0),
                externalChecks: new IMarketplace.ExternalCheck[](0)
            }),
            sent: new IMarketplace.Asset[](1),
            received: new IMarketplace.Asset[](1)
        });

        IMarketplace.Asset memory manaAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC20(),
            contractAddress: mana,
            value: 100 ether,
            beneficiary: address(0),
            extra: new bytes(0)
        });

        trade.received[0] = manaAsset;

        IMarketplace.Asset memory nftAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC721(),
            contractAddress: collection,
            value: collectionTokenId,
            beneficiary: address(this),
            extra: new bytes(0)
        });

        trade.sent[0] = nftAsset;

        (v, r, s) = vm.sign(sellerPk, creditsManager.tradeToTypedHashData(trade, marketplace));

        trade.signature = abi.encodePacked(r, s, v);

        IMarketplace.Trade[] memory trades = new IMarketplace.Trade[](1);
        trades[0] = trade;

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: marketplace,
            selector: IMarketplace.accept.selector,
            data: abi.encode(trades),
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

        vm.prank(seller);
        IERC721(collection).setApprovalForAll(marketplace, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.prank(owner);
        creditsManager.updateSecondarySalesAllowed(false);

        vm.expectRevert(CreditsManagerPolygon.SecondarySalesNotAllowed.selector);
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenSentAssetsIsEmpty() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, seller, collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        IMarketplace.Trade memory trade = IMarketplace.Trade({
            signer: seller,
            signature: "",
            checks: IMarketplace.Checks({
                uses: 1,
                expiration: type(uint256).max,
                effective: 0,
                salt: bytes32(0),
                contractSignatureIndex: 0,
                signerSignatureIndex: 0,
                allowedRoot: bytes32(0),
                allowedProof: new bytes32[](0),
                externalChecks: new IMarketplace.ExternalCheck[](0)
            }),
            sent: new IMarketplace.Asset[](0),
            received: new IMarketplace.Asset[](1)
        });

        IMarketplace.Asset memory manaAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC20(),
            contractAddress: mana,
            value: 100 ether,
            beneficiary: address(0),
            extra: new bytes(0)
        });

        trade.received[0] = manaAsset;

        (v, r, s) = vm.sign(sellerPk, creditsManager.tradeToTypedHashData(trade, marketplace));

        trade.signature = abi.encodePacked(r, s, v);

        IMarketplace.Trade[] memory trades = new IMarketplace.Trade[](1);
        trades[0] = trade;

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: marketplace,
            selector: IMarketplace.accept.selector,
            data: abi.encode(trades),
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

        vm.prank(seller);
        IERC721(collection).setApprovalForAll(marketplace, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.expectRevert(CreditsManagerPolygon.InvalidAssetsLength.selector);
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenReceivedAssetIsNotERC20OrUSDPeggedMANA() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, seller, collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        IMarketplace.Trade memory trade = IMarketplace.Trade({
            signer: seller,
            signature: "",
            checks: IMarketplace.Checks({
                uses: 1,
                expiration: type(uint256).max,
                effective: 0,
                salt: bytes32(0),
                contractSignatureIndex: 0,
                signerSignatureIndex: 0,
                allowedRoot: bytes32(0),
                allowedProof: new bytes32[](0),
                externalChecks: new IMarketplace.ExternalCheck[](0)
            }),
            sent: new IMarketplace.Asset[](1),
            received: new IMarketplace.Asset[](1)
        });

        IMarketplace.Asset memory manaAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC721(),
            contractAddress: mana,
            value: 100 ether,
            beneficiary: address(0),
            extra: new bytes(0)
        });

        trade.received[0] = manaAsset;

        IMarketplace.Asset memory nftAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC721(),
            contractAddress: collection,
            value: collectionTokenId,
            beneficiary: address(this),
            extra: new bytes(0)
        });

        trade.sent[0] = nftAsset;

        (v, r, s) = vm.sign(sellerPk, creditsManager.tradeToTypedHashData(trade, marketplace));

        trade.signature = abi.encodePacked(r, s, v);

        IMarketplace.Trade[] memory trades = new IMarketplace.Trade[](1);
        trades[0] = trade;

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: marketplace,
            selector: IMarketplace.accept.selector,
            data: abi.encode(trades),
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

        vm.prank(seller);
        IERC721(collection).setApprovalForAll(marketplace, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.InvalidTrade.selector, trade));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenMultipleAssetsAreReceived() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, seller, collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        IMarketplace.Trade memory trade = IMarketplace.Trade({
            signer: seller,
            signature: "",
            checks: IMarketplace.Checks({
                uses: 1,
                expiration: type(uint256).max,
                effective: 0,
                salt: bytes32(0),
                contractSignatureIndex: 0,
                signerSignatureIndex: 0,
                allowedRoot: bytes32(0),
                allowedProof: new bytes32[](0),
                externalChecks: new IMarketplace.ExternalCheck[](0)
            }),
            sent: new IMarketplace.Asset[](1),
            received: new IMarketplace.Asset[](2)
        });

        IMarketplace.Asset memory manaAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC20(),
            contractAddress: mana,
            value: 100 ether,
            beneficiary: address(0),
            extra: new bytes(0)
        });

        trade.received[0] = manaAsset;

        IMarketplace.Asset memory nftAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC721(),
            contractAddress: collection,
            value: collectionTokenId,
            beneficiary: address(this),
            extra: new bytes(0)
        });

        trade.sent[0] = nftAsset;

        (v, r, s) = vm.sign(sellerPk, creditsManager.tradeToTypedHashData(trade, marketplace));

        trade.signature = abi.encodePacked(r, s, v);

        IMarketplace.Trade[] memory trades = new IMarketplace.Trade[](1);
        trades[0] = trade;

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: marketplace,
            selector: IMarketplace.accept.selector,
            data: abi.encode(trades),
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

        vm.prank(seller);
        IERC721(collection).setApprovalForAll(marketplace, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.InvalidTrade.selector, trade));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenReceivedAssetIsNotMana() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, seller, collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        IMarketplace.Trade memory trade = IMarketplace.Trade({
            signer: seller,
            signature: "",
            checks: IMarketplace.Checks({
                uses: 1,
                expiration: type(uint256).max,
                effective: 0,
                salt: bytes32(0),
                contractSignatureIndex: 0,
                signerSignatureIndex: 0,
                allowedRoot: bytes32(0),
                allowedProof: new bytes32[](0),
                externalChecks: new IMarketplace.ExternalCheck[](0)
            }),
            sent: new IMarketplace.Asset[](1),
            received: new IMarketplace.Asset[](1)
        });

        IMarketplace.Asset memory manaAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC20(),
            contractAddress: address(0),
            value: 100 ether,
            beneficiary: address(0),
            extra: new bytes(0)
        });

        trade.received[0] = manaAsset;

        IMarketplace.Asset memory nftAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC721(),
            contractAddress: collection,
            value: collectionTokenId,
            beneficiary: address(this),
            extra: new bytes(0)
        });

        trade.sent[0] = nftAsset;

        (v, r, s) = vm.sign(sellerPk, creditsManager.tradeToTypedHashData(trade, marketplace));

        trade.signature = abi.encodePacked(r, s, v);

        IMarketplace.Trade[] memory trades = new IMarketplace.Trade[](1);
        trades[0] = trade;

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: marketplace,
            selector: IMarketplace.accept.selector,
            data: abi.encode(trades),
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

        vm.prank(seller);
        IERC721(collection).setApprovalForAll(marketplace, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.InvalidTrade.selector, trade));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenTradesIsEmpty() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, seller, collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        IMarketplace.Trade[] memory trades = new IMarketplace.Trade[](0);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: marketplace,
            selector: IMarketplace.accept.selector,
            data: abi.encode(trades),
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

        vm.prank(seller);
        IERC721(collection).setApprovalForAll(marketplace, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.expectRevert(CreditsManagerPolygon.InvalidTradesLength.selector);
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenSelectorIsInvalid() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, seller, collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        IMarketplace.Trade memory trade = IMarketplace.Trade({
            signer: seller,
            signature: "",
            checks: IMarketplace.Checks({
                uses: 1,
                expiration: type(uint256).max,
                effective: 0,
                salt: bytes32(0),
                contractSignatureIndex: 0,
                signerSignatureIndex: 0,
                allowedRoot: bytes32(0),
                allowedProof: new bytes32[](0),
                externalChecks: new IMarketplace.ExternalCheck[](0)
            }),
            sent: new IMarketplace.Asset[](1),
            received: new IMarketplace.Asset[](1)
        });

        IMarketplace.Asset memory manaAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC20(),
            contractAddress: mana,
            value: 100 ether,
            beneficiary: address(0),
            extra: new bytes(0)
        });

        trade.received[0] = manaAsset;

        IMarketplace.Asset memory nftAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC721(),
            contractAddress: collection,
            value: collectionTokenId,
            beneficiary: address(this),
            extra: new bytes(0)
        });

        trade.sent[0] = nftAsset;

        (v, r, s) = vm.sign(sellerPk, creditsManager.tradeToTypedHashData(trade, marketplace));

        trade.signature = abi.encodePacked(r, s, v);

        IMarketplace.Trade[] memory trades = new IMarketplace.Trade[](1);
        trades[0] = trade;

        CreditsManagerPolygon.ExternalCall memory externalCall =
            CreditsManagerPolygon.ExternalCall({target: marketplace, selector: bytes4(0), data: abi.encode(trades), expiresAt: 0, salt: bytes32(0)});

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: bytes(""),
            maxUncreditedValue: 0,
            maxCreditedValue: 100 ether
        });

        vm.prank(seller);
        IERC721(collection).setApprovalForAll(marketplace, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.InvalidExternalCallSelector.selector, marketplace, bytes4(0)));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenTheCallerIsTheSameAsTheSeller() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditsSignerPk, keccak256(abi.encode(seller, block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, seller, collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        IMarketplace.Trade memory trade = IMarketplace.Trade({
            signer: seller,
            signature: "",
            checks: IMarketplace.Checks({
                uses: 1,
                expiration: type(uint256).max,
                effective: 0,
                salt: bytes32(0),
                contractSignatureIndex: 0,
                signerSignatureIndex: 0,
                allowedRoot: bytes32(0),
                allowedProof: new bytes32[](0),
                externalChecks: new IMarketplace.ExternalCheck[](0)
            }),
            sent: new IMarketplace.Asset[](1),
            received: new IMarketplace.Asset[](1)
        });

        IMarketplace.Asset memory manaAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC20(),
            contractAddress: mana,
            value: 100 ether,
            beneficiary: address(0),
            extra: new bytes(0)
        });

        trade.received[0] = manaAsset;

        IMarketplace.Asset memory nftAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC721(),
            contractAddress: collection,
            value: collectionTokenId,
            beneficiary: seller,
            extra: new bytes(0)
        });

        trade.sent[0] = nftAsset;

        (v, r, s) = vm.sign(sellerPk, creditsManager.tradeToTypedHashData(trade, marketplace));

        trade.signature = abi.encodePacked(r, s, v);

        IMarketplace.Trade[] memory trades = new IMarketplace.Trade[](1);
        trades[0] = trade;

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: marketplace,
            selector: IMarketplace.accept.selector,
            data: abi.encode(trades),
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

        vm.prank(seller);
        IERC721(collection).setApprovalForAll(marketplace, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.expectRevert(CreditsManagerPolygon.SenderBalanceChanged.selector);
        vm.prank(seller);
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

        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, seller, collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        IMarketplace.Trade memory trade = IMarketplace.Trade({
            signer: seller,
            signature: "",
            checks: IMarketplace.Checks({
                uses: 1,
                expiration: type(uint256).max,
                effective: 0,
                salt: bytes32(0),
                contractSignatureIndex: 0,
                signerSignatureIndex: 0,
                allowedRoot: bytes32(0),
                allowedProof: new bytes32[](0),
                externalChecks: new IMarketplace.ExternalCheck[](0)
            }),
            sent: new IMarketplace.Asset[](1),
            received: new IMarketplace.Asset[](1)
        });

        IMarketplace.Asset memory manaAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC20(),
            contractAddress: mana,
            value: 100 ether,
            beneficiary: address(0),
            extra: new bytes(0)
        });

        trade.received[0] = manaAsset;

        IMarketplace.Asset memory nftAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC721(),
            contractAddress: collection,
            value: collectionTokenId,
            beneficiary: address(this),
            extra: new bytes(0)
        });

        trade.sent[0] = nftAsset;

        (v, r, s) = vm.sign(sellerPk, creditsManager.tradeToTypedHashData(trade, marketplace));

        trade.signature = abi.encodePacked(r, s, v);

        IMarketplace.Trade[] memory trades = new IMarketplace.Trade[](1);
        trades[0] = trade;

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: marketplace,
            selector: IMarketplace.accept.selector,
            data: abi.encode(trades),
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

        vm.prank(seller);
        IERC721(collection).setApprovalForAll(marketplace, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));
        uint256 sellerBalanceBefore = IERC20(mana).balanceOf(seller);
        uint256 buyerBalanceBefore = IERC20(mana).balanceOf(address(this));

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        creditsManager.useCredits(args);

        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 100 ether);
        assertEq(IERC20(mana).balanceOf(seller), sellerBalanceBefore + 100 ether - 2.5 ether); // 2.5% fee
        assertEq(IERC20(mana).balanceOf(address(this)), buyerBalanceBefore);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), address(this));
    }

    function test_useCredits_Success_MetaTx() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(creditsSignerPk, keccak256(abi.encode(metaTxSigner, block.chainid, address(creditsManager), credits[0])).toEthSignedMessageHash());

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, seller, collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        IMarketplace.Trade memory trade = IMarketplace.Trade({
            signer: seller,
            signature: "",
            checks: IMarketplace.Checks({
                uses: 1,
                expiration: type(uint256).max,
                effective: 0,
                salt: bytes32(0),
                contractSignatureIndex: 0,
                signerSignatureIndex: 0,
                allowedRoot: bytes32(0),
                allowedProof: new bytes32[](0),
                externalChecks: new IMarketplace.ExternalCheck[](0)
            }),
            sent: new IMarketplace.Asset[](1),
            received: new IMarketplace.Asset[](1)
        });

        IMarketplace.Asset memory manaAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC20(),
            contractAddress: mana,
            value: 100 ether,
            beneficiary: address(0),
            extra: new bytes(0)
        });

        trade.received[0] = manaAsset;

        IMarketplace.Asset memory nftAsset = IMarketplace.Asset({
            assetType: creditsManager.ASSET_TYPE_ERC721(),
            contractAddress: collection,
            value: collectionTokenId,
            beneficiary: metaTxSigner,
            extra: new bytes(0)
        });

        trade.sent[0] = nftAsset;

        (v, r, s) = vm.sign(sellerPk, creditsManager.tradeToTypedHashData(trade, marketplace));

        trade.signature = abi.encodePacked(r, s, v);

        IMarketplace.Trade[] memory trades = new IMarketplace.Trade[](1);
        trades[0] = trade;

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: marketplace,
            selector: IMarketplace.accept.selector,
            data: abi.encode(trades),
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

        vm.prank(seller);
        IERC721(collection).setApprovalForAll(marketplace, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));
        uint256 sellerBalanceBefore = IERC20(mana).balanceOf(seller);
        uint256 buyerBalanceBefore = IERC20(mana).balanceOf(metaTxSigner);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), seller);

        bytes memory metaTxFunctionData = abi.encodeWithSelector(CreditsManagerPolygon.useCredits.selector, args);

        (v, r, s) = vm.sign(metaTxSignerPk, creditsManager.metaTxToTypedHashData(metaTxSigner, metaTxFunctionData));

        bytes memory metaTxSignature = abi.encodePacked(r, s, v);

        creditsManager.executeMetaTransaction(metaTxSigner, metaTxFunctionData, metaTxSignature);

        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 100 ether);
        assertEq(IERC20(mana).balanceOf(seller), sellerBalanceBefore + 100 ether - 2.5 ether); // 2.5% fee
        assertEq(IERC20(mana).balanceOf(metaTxSigner), buyerBalanceBefore);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), metaTxSigner);
    }
}
