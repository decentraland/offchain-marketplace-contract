// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {CreditsManagerPolygonTestBase} from "test/credits/utils/CreditsManagerPolygonTestBase.sol";

contract CreditsManagerPolygonCoreTest is CreditsManagerPolygonTestBase {
    function test_constructor() public view {
        assertEq(creditsManager.hasRole(creditsManager.DEFAULT_ADMIN_ROLE(), owner), true);
        assertEq(creditsManager.hasRole(creditsManager.CREDITS_SIGNER_ROLE(), creditsSigner), true);
        assertEq(creditsManager.hasRole(creditsManager.PAUSER_ROLE(), pauser), true);
        assertEq(creditsManager.hasRole(creditsManager.PAUSER_ROLE(), owner), true);
        assertEq(creditsManager.hasRole(creditsManager.USER_DENIER_ROLE(), userDenier), true);
        assertEq(creditsManager.hasRole(creditsManager.USER_DENIER_ROLE(), owner), true);
        assertEq(creditsManager.hasRole(creditsManager.CREDITS_REVOKER_ROLE(), creditsRevoker), true);
        assertEq(creditsManager.hasRole(creditsManager.CREDITS_REVOKER_ROLE(), owner), true);
        assertEq(creditsManager.hasRole(creditsManager.EXTERNAL_CALL_SIGNER_ROLE(), customExternalCallSigner), true);
        assertEq(creditsManager.hasRole(creditsManager.EXTERNAL_CALL_REVOKER_ROLE(), customExternalCallRevoker), true);
        assertEq(creditsManager.hasRole(creditsManager.EXTERNAL_CALL_REVOKER_ROLE(), owner), true);

        assertEq(creditsManager.maxManaCreditedPerHour(), maxManaCreditedPerHour);
        assertEq(creditsManager.primarySalesAllowed(), primarySalesAllowed);
        assertEq(creditsManager.secondarySalesAllowed(), secondarySalesAllowed);

        assertEq(address(creditsManager.mana()), mana);
        assertEq(creditsManager.marketplace(), marketplace);
        assertEq(creditsManager.legacyMarketplace(), legacyMarketplace);
        assertEq(creditsManager.collectionStore(), collectionStore);
        assertEq(address(creditsManager.collectionFactory()), collectionFactory);
        assertEq(address(creditsManager.collectionFactoryV3()), collectionFactoryV3);
    }

    function test_pause_RevertsWhenNotPauser() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), creditsManager.PAUSER_ROLE()));
        creditsManager.pause();
    }

    function test_pause_WhenPauser() public {
        vm.prank(pauser);
        creditsManager.pause();
    }

    function test_pause_WhenOwner() public {
        vm.prank(owner);
        creditsManager.pause();
    }

    function test_unpause_RevertsWhenNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), creditsManager.DEFAULT_ADMIN_ROLE())
        );
        creditsManager.unpause();
    }

    function test_unpause_RevertsWhenPauser() public {
        vm.startPrank(pauser);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, pauser, creditsManager.DEFAULT_ADMIN_ROLE()));
        creditsManager.unpause();
        vm.stopPrank();
    }

    function test_unpause_WhenOwner() public {
        vm.startPrank(owner);
        creditsManager.pause();
        creditsManager.unpause();
        vm.stopPrank();
    }

    function test_denyUser_RevertsWhenNotDenier() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), creditsManager.USER_DENIER_ROLE()));
        creditsManager.denyUser(address(this));
    }

    function test_denyUser_WhenDenier() public {
        vm.expectEmit(address(creditsManager));
        emit UserDenied(userDenier, address(this));
        vm.prank(userDenier);
        creditsManager.denyUser(address(this));
        assertTrue(creditsManager.isDenied(address(this)));
    }

    function test_denyUser_WhenOwner() public {
        vm.expectEmit(address(creditsManager));
        emit UserDenied(owner, address(this));
        vm.prank(owner);
        creditsManager.denyUser(address(this));
        assertTrue(creditsManager.isDenied(address(this)));
    }

    function test_allowUser_RevertsWhenNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), creditsManager.DEFAULT_ADMIN_ROLE())
        );
        creditsManager.allowUser(address(this));
    }

    function test_allowUser_RevertsWhenDenier() public {
        vm.startPrank(userDenier);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, userDenier, creditsManager.DEFAULT_ADMIN_ROLE()));
        creditsManager.allowUser(address(this));
        vm.stopPrank();
    }

    function test_allowUser_WhenOwner() public {
        vm.expectEmit(address(creditsManager));
        emit UserAllowed(owner, address(this));
        vm.prank(owner);
        creditsManager.allowUser(address(this));
        assertFalse(creditsManager.isDenied(address(this)));
    }

    function test_revokeCredit_RevertsWhenNotRevoker() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), creditsManager.CREDITS_REVOKER_ROLE())
        );
        creditsManager.revokeCredit(bytes32(0));
    }

    function test_revokeCredit_WhenRevoker() public {
        vm.expectEmit(address(creditsManager));
        emit CreditRevoked(creditsRevoker, bytes32(0));
        vm.prank(creditsRevoker);
        creditsManager.revokeCredit(bytes32(0));
        assertTrue(creditsManager.isRevoked(bytes32(0)));
    }

    function test_revokeCredit_WhenOwner() public {
        vm.expectEmit(address(creditsManager));
        emit CreditRevoked(owner, bytes32(0));
        vm.prank(owner);
        creditsManager.revokeCredit(bytes32(0));
        assertTrue(creditsManager.isRevoked(bytes32(0)));
    }

    function test_updateMaxManaCreditedPerHour_RevertsWhenNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), creditsManager.DEFAULT_ADMIN_ROLE())
        );
        creditsManager.updateMaxManaCreditedPerHour(maxManaCreditedPerHour);
    }

    function test_updateMaxManaCreditedPerHour_WhenOwner() public {
        vm.expectEmit(address(creditsManager));
        emit MaxManaCreditedPerHourUpdated(owner, 1);
        vm.prank(owner);
        creditsManager.updateMaxManaCreditedPerHour(1);
        assertEq(creditsManager.maxManaCreditedPerHour(), 1);
    }

    function test_updatePrimarySalesAllowed_RevertsWhenNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), creditsManager.DEFAULT_ADMIN_ROLE())
        );
        creditsManager.updatePrimarySalesAllowed(primarySalesAllowed);
    }

    function test_updatePrimarySalesAllowed_WhenOwner() public {
        vm.expectEmit(address(creditsManager));
        emit PrimarySalesAllowedUpdated(owner, false);
        vm.prank(owner);
        creditsManager.updatePrimarySalesAllowed(false);
        assertEq(creditsManager.primarySalesAllowed(), false);

        vm.expectEmit(address(creditsManager));
        emit PrimarySalesAllowedUpdated(owner, true);
        vm.prank(owner);
        creditsManager.updatePrimarySalesAllowed(true);
        assertEq(creditsManager.primarySalesAllowed(), true);
    }

    function test_updateSecondarySalesAllowed_RevertsWhenNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), creditsManager.DEFAULT_ADMIN_ROLE())
        );
        creditsManager.updateSecondarySalesAllowed(secondarySalesAllowed);
    }

    function test_updateSecondarySalesAllowed_WhenOwner() public {
        vm.expectEmit(address(creditsManager));
        emit SecondarySalesAllowedUpdated(owner, false);
        vm.prank(owner);
        creditsManager.updateSecondarySalesAllowed(false);
        assertEq(creditsManager.secondarySalesAllowed(), false);

        vm.expectEmit(address(creditsManager));
        emit SecondarySalesAllowedUpdated(owner, true);
        vm.prank(owner);
        creditsManager.updateSecondarySalesAllowed(true);
        assertEq(creditsManager.secondarySalesAllowed(), true);
    }

    function test_allowCustomExternalCall_RevertsWhenNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), creditsManager.DEFAULT_ADMIN_ROLE())
        );
        creditsManager.allowCustomExternalCall(address(this), bytes4(0), true);
    }

    function test_allowCustomExternalCall_WhenOwner() public {
        vm.expectEmit(address(creditsManager));
        emit CustomExternalCallAllowed(owner, address(this), bytes4(0), true);
        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(this), bytes4(0), true);
    }

    function test_revokeCustomExternalCall_RevertsWhenNotCustomExternalCallRevoker() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), creditsManager.EXTERNAL_CALL_REVOKER_ROLE()
            )
        );
        creditsManager.revokeCustomExternalCall(bytes32(0));
    }

    function test_revokeCustomExternalCall_WhenCustomExternalCallRevoker() public {
        vm.expectEmit(address(creditsManager));
        emit CustomExternalCallRevoked(customExternalCallRevoker, bytes32(0));
        vm.prank(customExternalCallRevoker);
        creditsManager.revokeCustomExternalCall(bytes32(0));

        assertTrue(creditsManager.usedCustomExternalCallSignature(bytes32(0)));
    }

    function test_revokeCustomExternalCall_WhenOwner() public {
        vm.expectEmit(address(creditsManager));
        emit CustomExternalCallRevoked(owner, bytes32(0));
        vm.prank(owner);
        creditsManager.revokeCustomExternalCall(bytes32(0));

        assertTrue(creditsManager.usedCustomExternalCallSignature(bytes32(0)));
    }

    function test_withdrawERC20_RevertsWhenNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), creditsManager.DEFAULT_ADMIN_ROLE())
        );
        creditsManager.withdrawERC20(address(mana), 1 ether, address(this));
    }

    function test_withdrawERC20_WhenOwner() public {
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));

        vm.expectEmit(address(creditsManager));
        emit ERC20Withdrawn(owner, address(mana), 1 ether, owner);
        vm.prank(owner);
        creditsManager.withdrawERC20(address(mana), 1 ether, owner);

        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 1 ether);
        assertEq(IERC20(mana).balanceOf(owner), 1 ether);

        vm.expectEmit(address(creditsManager));
        emit ERC20Withdrawn(owner, address(mana), 1 ether, address(this));
        vm.prank(owner);
        creditsManager.withdrawERC20(address(mana), 1 ether, address(this));

        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 2 ether);
        assertEq(IERC20(mana).balanceOf(address(this)), 1 ether);
    }

    function test_withdrawERC721_RevertsWhenNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), creditsManager.DEFAULT_ADMIN_ROLE())
        );
        creditsManager.withdrawERC721(collection, collectionTokenId, address(this));
    }

    function test_withdrawERC721_WhenOwner() public {
        vm.prank(collectionTokenOwner);
        IERC721(collection).transferFrom(collectionTokenOwner, address(creditsManager), collectionTokenId);

        assertEq(IERC721(collection).ownerOf(collectionTokenId), address(creditsManager));

        vm.expectEmit(address(creditsManager));
        emit ERC721Withdrawn(owner, collection, collectionTokenId, address(this));
        vm.prank(owner);
        creditsManager.withdrawERC721(collection, collectionTokenId, address(this));

        assertEq(IERC721(collection).ownerOf(collectionTokenId), address(this));
    }
}
