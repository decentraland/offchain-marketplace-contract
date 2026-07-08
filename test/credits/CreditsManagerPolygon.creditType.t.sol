// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {CreditsManagerPolygon} from "src/credits/CreditsManagerPolygon.sol";
import {CreditsManagerPolygonTestBase} from "test/credits/utils/CreditsManagerPolygonTestBase.sol";
import {ICollectionStore} from "src/credits/interfaces/ICollectionStore.sol";

/// @notice Tests that primary/secondary sales and custom external call permissions are scoped per CreditType,
/// and that a single useCredits call cannot mix credits of different types.
contract CreditsManagerPolygonCreditTypeTest is CreditsManagerPolygonTestBase {
    using MessageHashUtils for bytes32;

    function _signCredit(uint256 _signerPk, address _caller, CreditsManagerPolygon.Credit memory _credit) private view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(_signerPk, keccak256(abi.encode(_caller, block.chainid, address(creditsManager), _credit)).toEthSignedMessageHash());

        return abi.encodePacked(r, s, v);
    }

    function _buildCollectionStoreArgs(CreditsManagerPolygon.Credit[] memory _credits, bytes[] memory _creditsSignatures)
        private
        view
        returns (CreditsManagerPolygon.UseCreditsArgs memory)
    {
        ICollectionStore.ItemToBuy[] memory itemsToBuy = new ICollectionStore.ItemToBuy[](1);

        itemsToBuy[0] =
            ICollectionStore.ItemToBuy({collection: collection, ids: new uint256[](1), prices: new uint256[](1), beneficiaries: new address[](1)});

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

        return CreditsManagerPolygon.UseCreditsArgs({
            credits: _credits,
            creditsSignatures: _creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: bytes(""),
            maxUncreditedValue: 0,
            maxCreditedValue: 369 ether
        });
    }

    function test_useCredits_RevertsWhenCreditsMixDifferentTypes() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](2);

        credits[0] = CreditsManagerPolygon.Credit({
            value: 200 ether,
            expiresAt: type(uint256).max,
            salt: bytes32(0),
            creditType: CreditsManagerPolygon.CreditType.SEASON
        });
        credits[1] = CreditsManagerPolygon.Credit({
            value: 169 ether,
            expiresAt: type(uint256).max,
            salt: bytes32(uint256(1)),
            creditType: CreditsManagerPolygon.CreditType.DIRECT
        });

        bytes[] memory creditsSignatures = new bytes[](2);
        creditsSignatures[0] = _signCredit(creditsSignerPk, address(this), credits[0]);
        creditsSignatures[1] = _signCredit(creditsSignerPk, address(this), credits[1]);

        CreditsManagerPolygon.UseCreditsArgs memory args = _buildCollectionStoreArgs(credits, creditsSignatures);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 369 ether);

        vm.prank(owner);
        creditsManager.updateMaxManaCreditedPerHour(369 ether);

        vm.expectRevert(CreditsManagerPolygon.MixedCreditTypes.selector);
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenNoCreditsProvided() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](0);
        bytes[] memory creditsSignatures = new bytes[](0);

        CreditsManagerPolygon.UseCreditsArgs memory args = _buildCollectionStoreArgs(credits, creditsSignatures);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 369 ether);

        vm.prank(owner);
        creditsManager.updateMaxManaCreditedPerHour(369 ether);

        vm.expectRevert(CreditsManagerPolygon.NoCredits.selector);
        creditsManager.useCredits(args);
    }

    function test_useCredits_PrimarySalesAllowedIsScopedPerCreditType() public {
        // Disable primary sales for DIRECT credits only. SEASON credits should be unaffected.
        vm.prank(owner);
        creditsManager.updatePrimarySalesAllowed(CreditsManagerPolygon.CreditType.DIRECT, false);

        assertFalse(creditsManager.primarySalesAllowed(CreditsManagerPolygon.CreditType.DIRECT));
        assertTrue(creditsManager.primarySalesAllowed(CreditsManagerPolygon.CreditType.SEASON));

        // A DIRECT credit purchase must revert.
        CreditsManagerPolygon.Credit[] memory directCredits = new CreditsManagerPolygon.Credit[](1);
        directCredits[0] = CreditsManagerPolygon.Credit({
            value: 369 ether,
            expiresAt: type(uint256).max,
            salt: bytes32(0),
            creditType: CreditsManagerPolygon.CreditType.DIRECT
        });

        bytes[] memory directCreditsSignatures = new bytes[](1);
        directCreditsSignatures[0] = _signCredit(creditsSignerPk, address(this), directCredits[0]);

        CreditsManagerPolygon.UseCreditsArgs memory directArgs = _buildCollectionStoreArgs(directCredits, directCreditsSignatures);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 369 ether);

        vm.prank(owner);
        creditsManager.updateMaxManaCreditedPerHour(type(uint256).max);

        vm.expectRevert(CreditsManagerPolygon.PrimarySalesNotAllowed.selector);
        creditsManager.useCredits(directArgs);

        // A SEASON credit purchase for the same amount must still succeed.
        CreditsManagerPolygon.Credit[] memory seasonCredits = new CreditsManagerPolygon.Credit[](1);
        seasonCredits[0] = CreditsManagerPolygon.Credit({
            value: 369 ether,
            expiresAt: type(uint256).max,
            salt: bytes32(uint256(1)),
            creditType: CreditsManagerPolygon.CreditType.SEASON
        });

        bytes[] memory seasonCreditsSignatures = new bytes[](1);
        seasonCreditsSignatures[0] = _signCredit(creditsSignerPk, address(this), seasonCredits[0]);

        CreditsManagerPolygon.UseCreditsArgs memory seasonArgs = _buildCollectionStoreArgs(seasonCredits, seasonCreditsSignatures);

        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));

        creditsManager.useCredits(seasonArgs);

        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 369 ether);
    }
}
