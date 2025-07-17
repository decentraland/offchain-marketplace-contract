// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {CreditsManagerPolygonWithMANAClaimTestBase} from "test/credits/utils/CreditsManagerPolygonWithMANAClaimTestBase.sol";
import {CreditsManagerPolygonWithMANAClaim as CreditsManagerPolygon} from "src/credits/CreditsManagerPolygonWithMANAClaim.sol";
import {ICollection as ICollectionBase} from "src/marketplace/interfaces/ICollection.sol";

interface ICollectionManager {
    struct ItemParam {
        string rarity;
        uint256 price;
        address beneficiary;
        string metadata;
    }

    function createCollection(
        address _forwarder,
        address _factory,
        bytes32 _salt,
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        address _creator,
        ItemParam[] memory _items
    ) external;
}

interface ICollection is ICollectionBase {
    function owner() external view returns (address);
}

contract CreditsManagerPolygonWithMANAClaimUseCreditsPublishCollectionTest is CreditsManagerPolygonWithMANAClaimTestBase {
    using MessageHashUtils for bytes32;

    address internal collectionManager;
    address internal forwarder;

    function _sign(uint256 _key, bytes32 _messageHash) private pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, _messageHash.toEthSignedMessageHash());

        bytes memory signature = abi.encodePacked(r, s, v);

        return signature;
    }

    function setUp() public override {
        super.setUp();

        collectionManager = 0x9D32AaC179153A991e832550d9F96441Ea27763A;
        forwarder = 0xBF6755A83C0dCDBB2933A96EA778E00b717d7004;
    }

    function test_useCredits_PublishCollection() public {
        bytes4 createCollectionSelector = ICollectionManager(collectionManager).createCollection.selector;

        // Create Collection Items
        ICollectionManager.ItemParam[] memory items = new ICollectionManager.ItemParam[](1);
        items[0].rarity = "common";
        items[0].price = 0;
        items[0].beneficiary = address(0);
        items[0].metadata = "metadata";

        // Create Collection External Call
        CreditsManagerPolygon.ExternalCall memory externalCall;
        externalCall.target = collectionManager;
        externalCall.selector = createCollectionSelector;
        externalCall.expiresAt = type(uint256).max;
        externalCall.data = abi.encode(
            forwarder,
            collectionFactoryV3,
            bytes32(0),
            "CreditsManagerPublishCollectionCollectionName",
            "CreditsManagerPublishCollectionCollectionSymbol",
            "CreditsManagerPublishCollectionBaseURI",
            address(this),
            items
        );

        // External Call Signature
        bytes memory customExternalCallSignature =
            _sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

        // Credits
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);
        credits[0].value = 1000 ether;
        credits[0].expiresAt = type(uint256).max;

        // Credits Signatures
        bytes[] memory creditsSignatures = new bytes[](1);
        creditsSignatures[0] = _sign(creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        // Use Credits Args
        CreditsManagerPolygon.UseCreditsArgs memory args;
        args.credits = credits;
        args.creditsSignatures = creditsSignatures;
        args.externalCall = externalCall;
        args.customExternalCallSignature = customExternalCallSignature;
        args.maxCreditedValue = type(uint256).max;

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(collectionManager, createCollectionSelector, true);

        vm.prank(owner);
        creditsManager.updateMaxManaCreditedPerHour(type(uint256).max);

        uint256 callerBalanceBefore = IERC20(mana).balanceOf(address(this));
        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));

        creditsManager.useCredits(args);

        uint256 callerBalancerAfter = IERC20(mana).balanceOf(address(this));
        uint256 creditsManagerBalanceAfter = IERC20(mana).balanceOf(address(creditsManager));

        uint256 expectedPublishCollectionCost = 363151721157582426361;

        assertEq(callerBalancerAfter, callerBalanceBefore);
        assertEq(creditsManagerBalanceAfter, creditsManagerBalanceBefore - expectedPublishCollectionCost);

        address expectedPublishedCollectionAddress = 0x0B3f057FcCC5b9ef368A6Acac654B0C4cB95F06b;

        assertEq(ICollection(expectedPublishedCollectionAddress).creator(), address(this));
        assertEq(ICollection(expectedPublishedCollectionAddress).owner(), forwarder);
    }

    function test_useCredits_PublishCollection_MetaTx() public {
        bytes4 createCollectionSelector = ICollectionManager(collectionManager).createCollection.selector;

        // Create Collection Items
        ICollectionManager.ItemParam[] memory items = new ICollectionManager.ItemParam[](1);
        items[0].rarity = "common";
        items[0].price = 0;
        items[0].beneficiary = address(0);
        items[0].metadata = "metadata";

        // Create Collection External Call
        CreditsManagerPolygon.ExternalCall memory externalCall;
        externalCall.target = collectionManager;
        externalCall.selector = createCollectionSelector;
        externalCall.expiresAt = type(uint256).max;
        externalCall.data = abi.encode(
            forwarder,
            collectionFactoryV3,
            bytes32(0),
            "CreditsManagerPublishCollectionCollectionName",
            "CreditsManagerPublishCollectionCollectionSymbol",
            "CreditsManagerPublishCollectionBaseURI",
            metaTxSigner,
            items
        );

        // External Call Signature
        bytes memory customExternalCallSignature =
            _sign(customExternalCallSignerPk, keccak256(abi.encode(metaTxSigner, block.chainid, address(creditsManager), externalCall)));

        // Credits
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);
        credits[0].value = 1000 ether;
        credits[0].expiresAt = type(uint256).max;

        // Credits Signatures
        bytes[] memory creditsSignatures = new bytes[](1);
        creditsSignatures[0] = _sign(creditsSignerPk, keccak256(abi.encode(metaTxSigner, block.chainid, address(creditsManager), credits[0])));

        // Use Credits Args
        CreditsManagerPolygon.UseCreditsArgs memory args;
        args.credits = credits;
        args.creditsSignatures = creditsSignatures;
        args.externalCall = externalCall;
        args.customExternalCallSignature = customExternalCallSignature;
        args.maxCreditedValue = type(uint256).max;

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(collectionManager, createCollectionSelector, true);

        vm.prank(owner);
        creditsManager.updateMaxManaCreditedPerHour(type(uint256).max);

        uint256 callerBalanceBefore = IERC20(mana).balanceOf(metaTxSigner);
        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));

        bytes memory metaTxFunctionData = abi.encodeCall(creditsManager.useCredits, (args));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(metaTxSignerPk, creditsManager.metaTxToTypedHashData(metaTxSigner, metaTxFunctionData));
        bytes memory metaTxSignature = abi.encodePacked(r, s, v);

        creditsManager.executeMetaTransaction(metaTxSigner, metaTxFunctionData, metaTxSignature);

        uint256 callerBalancerAfter = IERC20(mana).balanceOf(metaTxSigner);
        uint256 creditsManagerBalanceAfter = IERC20(mana).balanceOf(address(creditsManager));

        uint256 expectedPublishCollectionCost = 363151721157582426361;

        assertEq(callerBalancerAfter, callerBalanceBefore);
        assertEq(creditsManagerBalanceAfter, creditsManagerBalanceBefore - expectedPublishCollectionCost);

        address expectedPublishedCollectionAddress = 0x23b6e935D32C6E36dE8438fE341902715A61e989;

        assertEq(ICollection(expectedPublishedCollectionAddress).creator(), metaTxSigner);
        assertEq(ICollection(expectedPublishedCollectionAddress).owner(), forwarder);
    }
}
