// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {CreditsManagerPolygonWithMANAClaim as CreditsManagerPolygon} from "src/credits/CreditsManagerPolygonWithMANAClaim.sol";
import {MockExternalCallTargetWithMANAClaim} from "test/credits/mocks/MockExternalCallTargetWithMANAClaim.sol";
import {CreditsManagerPolygonWithMANAClaimTestBase} from "test/credits/utils/CreditsManagerPolygonWithMANAClaimTestBase.sol";

contract CreditsManagerPolygonWithMANAClaimUseCreditsCustomExternalCallTest is CreditsManagerPolygonWithMANAClaimTestBase {
    using MessageHashUtils for bytes32;

    function test_useCredits_RevertsWhenCustomExternalCallNotAllowed() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        CreditsManagerPolygon.ExternalCall memory externalCall =
            CreditsManagerPolygon.ExternalCall({target: address(0), selector: bytes4(0), data: bytes(""), expiresAt: 0, salt: bytes32(0)});

        bytes memory customExternalCallSignature = bytes("");

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0,
            maxCreditedValue: 1
        });

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.CustomExternalCallNotAllowed.selector, address(0), bytes4(0)));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCustomExternalCallHasExpired() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        CreditsManagerPolygon.ExternalCall memory externalCall =
            CreditsManagerPolygon.ExternalCall({target: address(0), selector: bytes4(0), data: bytes(""), expiresAt: 0, salt: bytes32(0)});

        bytes memory customExternalCallSignature = bytes("");

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0,
            maxCreditedValue: 1
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(0), bytes4(0), true);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.CustomExternalCallExpired.selector, 0));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCustomExternalCallHasExpired_Inclusive() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(0),
            selector: bytes4(0),
            data: bytes(""),
            expiresAt: block.timestamp,
            salt: bytes32(0)
        });

        bytes memory customExternalCallSignature = bytes("");

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0,
            maxCreditedValue: 1
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(0), bytes4(0), true);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.CustomExternalCallExpired.selector, block.timestamp));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCustomExternalCallECDSAInvalidSignatureLength() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(0),
            selector: bytes4(0),
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        bytes memory customExternalCallSignature = bytes("");

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0,
            maxCreditedValue: 1
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(0), bytes4(0), true);

        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureLength.selector, 0));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenInvalidCustomExternalCallSignature() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(0),
            selector: bytes4(0),
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid + 1, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0,
            maxCreditedValue: 1
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(0), bytes4(0), true);

        vm.expectRevert(
            abi.encodeWithSelector(CreditsManagerPolygon.InvalidCustomExternalCallSignature.selector, 0x6237cF0957Bb2455F0BdB0D7c4545780bAa56Ff5)
        );
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenNoManaWasTransferred() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 0);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0,
            maxCreditedValue: 1
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.NoMANATransfer.selector));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenNotEnoughManaWasApproved() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0,
            maxCreditedValue: 1
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.ExternalCallFailed.selector, externalCall));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCallerBalanceIsNotEnough() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 1 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCallerDidNotApproveEnoughMana() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 1 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCreditsManagerDoesNotHaveEnoughMana() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 1 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.ExternalCallFailed.selector, externalCall));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenTheCallerBalanceIsUpdated() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);
        externalCallTarget.setBeneficiary(address(this));

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 1 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.expectRevert(CreditsManagerPolygon.SenderBalanceChanged.selector);
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCreditDoesNotHaveEnoughValue() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 1 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.expectRevert(CreditsManagerPolygon.InvalidCreditValue.selector);
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCreditIsExpired() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        bytes32 creditHash = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0]));

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 1 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.CreditExpired.selector, creditHash));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCreditIsExpired_Inclusive() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: block.timestamp, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        bytes32 creditHash = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0]));

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 1 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.CreditExpired.selector, creditHash));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCreditECDSAInvalidSignatureLength() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 1 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureLength.selector, 0));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCreditInvalidSignature() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        bytes32 creditHash = keccak256(abi.encode(address(this), block.chainid + 1, address(creditsManager), credits[0]));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditsSignerPk, creditHash.toEthSignedMessageHash());

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 1 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                CreditsManagerPolygon.InvalidSignature.selector,
                0x4a339faaf862ce8bfb01dc6715bdbcdbe6593cd692b533b151470b729fcdd0f5,
                0xD3e688B176Bdfe10E6CFBAf831728A8B50d92367
            )
        );
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenMaxCreditedValueExceeded() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])).toEthSignedMessageHash()
        );

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 1 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.MaxCreditedValueExceeded.selector, 100 ether, 1 ether));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenMaxManaCreditedPerHourExceeded() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 101 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])).toEthSignedMessageHash()
        );

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 101 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 101 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.MaxManaCreditedPerHourExceeded.selector, 100 ether, 101 ether));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenMaxManaCreditedPerHourExceeded_DifferentCalls() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 200 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])).toEthSignedMessageHash()
        );

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 51 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 51 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), type(uint256).max);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        creditsManager.useCredits(args);

        externalCall.salt = bytes32(uint256(1));
        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );
        args.customExternalCallSignature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.MaxManaCreditedPerHourExceeded.selector, 49 ether, 51 ether));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenExecuteCallIsReused() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 200 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])).toEthSignedMessageHash()
        );

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 51 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        bytes32 customExternalCallHash = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall));

        (v, r, s) = vm.sign(customExternalCallSignerPk, customExternalCallHash.toEthSignedMessageHash());

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 51 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), type(uint256).max);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        creditsManager.useCredits(args);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.UsedCustomExternalCall.selector, customExternalCallHash));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenUserIsDenied() public {
        vm.prank(userDenier);
        address[] memory users = new address[](1);
        users[0] = address(this);
        bool[] memory areDenied = new bool[](1);
        areDenied[0] = true;
        creditsManager.denyUsers(users, areDenied);

        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])).toEthSignedMessageHash()
        );

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 100 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.DeniedUser.selector, address(this)));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCreditWasRevoked() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        bytes32 creditHash = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0]));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditsSignerPk, creditHash.toEthSignedMessageHash());

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        bytes32[] memory revokedCredits = new bytes32[](1);
        revokedCredits[0] = creditHash;
        vm.prank(owner);
        creditsManager.revokeCredits(revokedCredits);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 100 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.RevokedCredit.selector, creditHash));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenMaxUncreditedValueIsExceeded() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 50 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])).toEthSignedMessageHash()
        );

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0 ether,
            maxCreditedValue: 100 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 50 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 50 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 100 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.MaxUncreditedValueExceeded.selector, 50 ether, 0));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenNoCreditsAreProvided() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](0);

        bytes[] memory creditsSignatures = new bytes[](0);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 100 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.NoCredits.selector));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCreditsAndSignaturesLengthsDiffer() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](0);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 100 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.InvalidCreditsSignaturesLength.selector));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenMaxCreditedValueIsZero() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])).toEthSignedMessageHash()
        );

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 100 ether,
            maxCreditedValue: 0
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 100 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.MaxCreditedValueZero.selector));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCreditIsFullyConsumed() public {
        // Create a credit with a specific value
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);
        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        bytes32 creditHash = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0]));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditsSignerPk, creditHash.toEthSignedMessageHash());

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        // Create an external call target that will consume exactly the credit amount
        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );
        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0 ether,
            maxCreditedValue: 100 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        // Transfer MANA to the credits manager to simulate available balance
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        // First call - consume the credit fully
        creditsManager.useCredits(args);

        // Verify the credit was fully consumed
        assertEq(creditsManager.spentValue(creditHash), 100 ether);

        // Create a new external call with a different salt to avoid UsedCustomExternalCall error
        CreditsManagerPolygon.ExternalCall memory externalCall2 = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(uint256(1)) // Different salt
        });

        externalCall2.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall2)).toEthSignedMessageHash()
        );
        bytes memory customExternalCallSignature2 = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args2 = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall2,
            customExternalCallSignature: customExternalCallSignature2,
            maxUncreditedValue: 0 ether,
            maxCreditedValue: 100 ether
        });

        // Warp to the next hour.
        // This is required because the credits manager uses the current hour to determine how much MANA can be credited.
        // Warping to the next hour resets the creditable amount.
        vm.warp(block.timestamp + 1 hours);

        // Second call - should revert with CreditConsumed
        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.CreditConsumed.selector, creditHash));
        creditsManager.useCredits(args2);
    }

    function test_useCredits_Success() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        bytes32 creditHash = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0]));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditsSignerPk, creditHash.toEthSignedMessageHash());

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 100 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        uint256 callerBalanceBefore = IERC20(mana).balanceOf(address(this));
        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));
        uint256 externalCallTargetBalanceBefore = IERC20(mana).balanceOf(address(externalCallTarget));

        assertEq(creditsManager.spentValue(creditHash), 0);

        vm.expectEmit(address(creditsManager));
        emit CreditUsed(address(this), creditHash, credits[0], 100 ether);
        vm.expectEmit(address(creditsManager));
        emit CreditsUsed(address(this), 100 ether, 100 ether);
        creditsManager.useCredits(args);

        assertEq(creditsManager.spentValue(creditHash), 100 ether);

        assertEq(IERC20(mana).balanceOf(address(this)), callerBalanceBefore);
        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 100 ether);
        assertEq(IERC20(mana).balanceOf(address(externalCallTarget)), externalCallTargetBalanceBefore + 100 ether);
    }

    function test_useCredits_CreditsManagerAsBeneficiary_RevertsIfEverythingIsReturned() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])).toEthSignedMessageHash()
        );

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);
        externalCallTarget.setBeneficiary(address(creditsManager));

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 100 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        assertEq(creditsManager.spentValue(keccak256(creditsSignatures[0])), 0);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.NoMANATransfer.selector));
        creditsManager.useCredits(args);
    }

    function test_useCredits_CreditsManagerAsBeneficiary_AccountingNotAffectedByRefund() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        // Credit is worth 500 mana
        credits[0] = CreditsManagerPolygon.Credit({value: 500 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        bytes32 creditHash = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0]));

        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditsSignerPk, creditHash.toEthSignedMessageHash());

            creditsSignatures[0] = abi.encodePacked(r, s, v);
        }

        // Item with cost 500 mana
        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 500 ether);

        // From the 500, 100 is transferred back to the credits manager
        externalCallTarget.setBeneficiary(address(creditsManager));
        externalCallTarget.setBeneficiaryCut(100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        bytes memory customExternalCallSignature;

        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                customExternalCallSignerPk,
                keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
            );

            customExternalCallSignature = abi.encodePacked(r, s, v);
        }

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            // The user defines that they want to use the whole 500, and 100 extra just in case out of pocket.
            maxUncreditedValue: 100 ether,
            maxCreditedValue: 500 ether
        });

        vm.prank(owner);
        creditsManager.updateMaxManaCreditedPerHour(1000 ether);

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 100 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        uint256 callerBalanceBefore = IERC20(mana).balanceOf(address(this));
        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));
        uint256 externalCallTargetBalanceBefore = IERC20(mana).balanceOf(address(externalCallTarget));

        assertEq(creditsManager.spentValue(creditHash), 0);

        // The mana transferred diff ends up being 400 because the credits manager was refunded 100 on the external call
        uint256 expectedCreditedAmount = 400 ether;

        vm.expectEmit(address(creditsManager));
        emit CreditUsed(address(this), creditHash, credits[0], expectedCreditedAmount);
        vm.expectEmit(address(creditsManager));
        emit CreditsUsed(address(this), expectedCreditedAmount, expectedCreditedAmount);
        creditsManager.useCredits(args);

        // 400 are used instead of the 500
        assertEq(creditsManager.spentValue(creditHash), expectedCreditedAmount);
        // 100 was taken initialy from the caller as that much was expected to be paid out of pocket,
        // but given that it was not necessary, it was returned and the caller balance is the same as before
        assertEq(IERC20(mana).balanceOf(address(this)), callerBalanceBefore);
        // The credits manager balance is reduced by the 400 used as credits
        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - expectedCreditedAmount);
        // The external call target balance is increased by the 400 credited.
        // It would have been 500 but the the external call target returned 100 to the credits manager.
        // The only loser in this operation is the seller (external call target:
        // - The buyer used less credits
        // - The credits manager had a net credit transfer, meaning nothing was lost that was not supposed to be lost
        // - The external call target lost 100 MANA by transfering it to the credits manager
        assertEq(IERC20(mana).balanceOf(address(externalCallTarget)), externalCallTargetBalanceBefore + expectedCreditedAmount);
    }

    function test_useCredits_Success_MaxManaCreditedPerHourIsResetAfterHour() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 200 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        bytes32 creditHash = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0]));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditsSignerPk, creditHash.toEthSignedMessageHash());

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );

        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 100 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 200 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        uint256 callerBalanceBefore = IERC20(mana).balanceOf(address(this));
        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));
        uint256 externalCallTargetBalanceBefore = IERC20(mana).balanceOf(address(externalCallTarget));

        assertEq(creditsManager.spentValue(creditHash), 0);

        vm.expectEmit(address(creditsManager));
        emit CreditUsed(address(this), creditHash, credits[0], 100 ether);
        vm.expectEmit(address(creditsManager));
        emit CreditsUsed(address(this), 100 ether, 100 ether);
        creditsManager.useCredits(args);

        assertEq(creditsManager.spentValue(creditHash), 100 ether);

        assertEq(IERC20(mana).balanceOf(address(this)), callerBalanceBefore);
        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 100 ether);
        assertEq(IERC20(mana).balanceOf(address(externalCallTarget)), externalCallTargetBalanceBefore + 100 ether);

        externalCall.salt = bytes32(uint256(1));
        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );
        args.customExternalCallSignature = abi.encodePacked(r, s, v);

        vm.warp(block.timestamp + 1 hours);

        assertEq(creditsManager.spentValue(creditHash), 100 ether);

        creditsManager.useCredits(args);

        assertEq(creditsManager.spentValue(creditHash), 200 ether);

        assertEq(IERC20(mana).balanceOf(address(this)), callerBalanceBefore);
        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 200 ether);
        assertEq(IERC20(mana).balanceOf(address(externalCallTarget)), externalCallTargetBalanceBefore + 200 ether);
    }

    function test_useCredits_Success_TwoCredits() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](2);

        credits[0] = CreditsManagerPolygon.Credit({value: 50 ether, expiresAt: type(uint256).max, salt: bytes32(0)});
        credits[1] = CreditsManagerPolygon.Credit({value: 50 ether, expiresAt: type(uint256).max, salt: bytes32(uint256(1))});

        bytes[] memory creditsSignatures = new bytes[](2);

        bytes32 creditHash1;
        bytes32 creditHash2;

        {
            creditHash1 = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0]));

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditsSignerPk, creditHash1.toEthSignedMessageHash());

            creditsSignatures[0] = abi.encodePacked(r, s, v);

            creditHash2 = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[1]));

            (v, r, s) = vm.sign(creditsSignerPk, creditHash2.toEthSignedMessageHash());

            creditsSignatures[1] = abi.encodePacked(r, s, v);
        }

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        bytes memory customExternalCallSignature;

        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                customExternalCallSignerPk,
                keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
            );

            customExternalCallSignature = abi.encodePacked(r, s, v);
        }

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 100 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        assertEq(creditsManager.spentValue(creditHash1), 0);
        assertEq(creditsManager.spentValue(creditHash2), 0);

        uint256 callerBalanceBefore = IERC20(mana).balanceOf(address(this));
        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));
        uint256 externalCallTargetBalanceBefore = IERC20(mana).balanceOf(address(externalCallTarget));

        vm.expectEmit(address(creditsManager));
        emit CreditUsed(address(this), creditHash1, credits[0], 50 ether);
        vm.expectEmit(address(creditsManager));
        emit CreditUsed(address(this), creditHash2, credits[1], 50 ether);
        vm.expectEmit(address(creditsManager));
        emit CreditsUsed(address(this), 100 ether, 100 ether);
        creditsManager.useCredits(args);

        assertEq(creditsManager.spentValue(creditHash1), 50 ether);
        assertEq(creditsManager.spentValue(creditHash2), 50 ether);

        assertEq(IERC20(mana).balanceOf(address(this)), callerBalanceBefore);
        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 100 ether);
        assertEq(IERC20(mana).balanceOf(address(externalCallTarget)), externalCallTargetBalanceBefore + 100 ether);
    }

    function test_useCredits_Success_TwoCredits_WithUncreditedValue() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](2);

        credits[0] = CreditsManagerPolygon.Credit({value: 50 ether, expiresAt: type(uint256).max, salt: bytes32(0)});
        credits[1] = CreditsManagerPolygon.Credit({value: 25 ether, expiresAt: type(uint256).max, salt: bytes32(uint256(1))});

        bytes[] memory creditsSignatures = new bytes[](2);

        bytes32 creditHash1;
        bytes32 creditHash2;

        {
            creditHash1 = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0]));

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditsSignerPk, creditHash1.toEthSignedMessageHash());

            creditsSignatures[0] = abi.encodePacked(r, s, v);

            creditHash2 = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[1]));

            (v, r, s) = vm.sign(creditsSignerPk, creditHash2.toEthSignedMessageHash());

            creditsSignatures[1] = abi.encodePacked(r, s, v);
        }

        MockExternalCallTargetWithMANAClaim externalCallTarget = new MockExternalCallTargetWithMANAClaim(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        bytes memory customExternalCallSignature;

        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                customExternalCallSignerPk,
                keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
            );

            customExternalCallSignature = abi.encodePacked(r, s, v);
        }

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 99 ether,
            maxCreditedValue: 100 ether
        });

        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(externalCallTarget), externalCallTarget.someFunction.selector, true);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(this), 1000 ether);

        vm.prank(address(this));
        IERC20(mana).approve(address(creditsManager), 99 ether);

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1000 ether);

        assertEq(creditsManager.spentValue(creditHash1), 0);
        assertEq(creditsManager.spentValue(creditHash2), 0);

        uint256 callerBalanceBefore = IERC20(mana).balanceOf(address(this));
        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));
        uint256 externalCallTargetBalanceBefore = IERC20(mana).balanceOf(address(externalCallTarget));

        vm.expectEmit(address(creditsManager));
        emit CreditUsed(address(this), creditHash1, credits[0], 50 ether);
        vm.expectEmit(address(creditsManager));
        emit CreditUsed(address(this), creditHash2, credits[1], 25 ether);
        vm.expectEmit(address(creditsManager));
        emit CreditsUsed(address(this), 100 ether, 75 ether);
        creditsManager.useCredits(args);

        assertEq(creditsManager.spentValue(creditHash1), 50 ether);
        assertEq(creditsManager.spentValue(creditHash2), 25 ether);

        assertEq(IERC20(mana).balanceOf(address(this)), callerBalanceBefore - 25 ether);
        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 75 ether);
        assertEq(IERC20(mana).balanceOf(address(externalCallTarget)), externalCallTargetBalanceBefore + 100 ether);
    }

    // ========================================
    // MANA CLAIM TESTS (NEW FUNCTIONALITY)
    // ========================================

    function test_useCredits_ManaClaim_RevertsWhenMaxUncreditedValueIsNotZero() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 1 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creditsSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])).toEthSignedMessageHash()
        );

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        // Create external call targeting MANA contract
        bytes memory transferData = abi.encodeWithSelector(IERC20.transfer.selector, address(this), 1 ether);
        
        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(mana),
            selector: IERC20.transfer.selector,
            data: transferData,
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: bytes(""), // No signature required for MANA calls
            maxUncreditedValue: 1 ether, // This should cause revert
            maxCreditedValue: 1 ether
        });

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1 ether);

        vm.prank(owner);
        creditsManager.updateMaxManaCreditedPerHour(1 ether);

        // Should revert because maxUncreditedValue > 0 for MANA calls
        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.MaxUncreditedValueExceeded.selector, 1 ether, 0));
        creditsManager.useCredits(args);
    }

    function test_useCredits_Claim_MANA_Success() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 1 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        bytes32 creditHash = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0]));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditsSignerPk, creditHash.toEthSignedMessageHash());

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        // Create external call targeting MANA contract for transfer to beneficiary
        bytes memory transferData = abi.encode(address(this), 1 ether);
        
        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(mana),
            selector: IERC20.transfer.selector,
            data: transferData,
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );
        
        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0, // Must be 0 for MANA calls
            maxCreditedValue: 1 ether
        });

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1 ether);

        vm.prank(owner);
        creditsManager.updateMaxManaCreditedPerHour(1 ether);
        
        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(mana), IERC20.transfer.selector, true);

        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));
        uint256 beneficiaryBalanceBefore = IERC20(mana).balanceOf(address(this));
        uint256 allowanceBefore = IERC20(mana).allowance(address(creditsManager), address(this));
        
        // This call should be allowed without pre-approval for MANA target
        vm.expectEmit(address(creditsManager));
        emit CreditUsed(address(this), creditHash, credits[0], 1 ether);

        vm.expectEmit(address(creditsManager));
        emit CreditsUsed(address(this), 1 ether, 1 ether);

        uint256 manaBalance = IERC20(mana).balanceOf(address(creditsManager));

        assertEq(manaBalance, 1 ether);

        creditsManager.useCredits(args);

        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 1 ether);
        assertEq(creditsManager.spentValue(creditHash), 1 ether);
    }

    function test_useCredits_Claim_MANA_RevertsWhenTheCallerUseOwnMANA_uncreditedValue_gt_0() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 1 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        bytes32 creditHash = keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0]));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditsSignerPk, creditHash.toEthSignedMessageHash());

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        // Create external call targeting MANA contract for transfer to beneficiary
        bytes memory transferData = abi.encode(address(this), 1 ether);
        
        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(mana),
            selector: IERC20.transfer.selector,
            data: transferData,
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        (v, r, s) = vm.sign(
            customExternalCallSignerPk,
            keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)).toEthSignedMessageHash()
        );
        
        bytes memory customExternalCallSignature = abi.encodePacked(r, s, v);

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0.1 ether, // Must be 0 for MANA calls
            maxCreditedValue: 1 ether
        });

        vm.prank(manaHolder);
        IERC20(mana).transfer(address(creditsManager), 1 ether);

        vm.prank(owner);
        creditsManager.updateMaxManaCreditedPerHour(1 ether);
        
        vm.prank(owner);
        creditsManager.allowCustomExternalCall(address(mana), IERC20.transfer.selector, true);

        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));
        uint256 beneficiaryBalanceBefore = IERC20(mana).balanceOf(address(this));
        uint256 allowanceBefore = IERC20(mana).allowance(address(creditsManager), address(this));
        

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.MaxUncreditedValueExceeded.selector, 0.1 ether, 0));
        creditsManager.useCredits(args);
    }    
}
