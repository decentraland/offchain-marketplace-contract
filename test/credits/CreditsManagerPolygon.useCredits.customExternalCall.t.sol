// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {CreditsManagerPolygon} from "src/credits/CreditsManagerPolygon.sol";
import {MockExternalCallTarget} from "test/credits/mocks/MockExternalCallTarget.sol";
import {CreditsManagerPolygonTestBase} from "test/credits/utils/CreditsManagerPolygonTestBase.sol";

contract CreditsManagerPolygonUseCreditsCustomExternalCallTest is CreditsManagerPolygonTestBase {
    function test_useCredits_RevertsWhenNoCredits() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](0);

        bytes[] memory creditsSignatures = new bytes[](0);

        CreditsManagerPolygon.ExternalCall memory externalCall =
            CreditsManagerPolygon.ExternalCall({target: address(this), selector: bytes4(0), data: bytes(""), expiresAt: 0, salt: bytes32(0)});

        bytes memory customExternalCallSignature = bytes("");

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0,
            maxCreditedValue: 0
        });

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.NoCredits.selector));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCreditsSignaturesLengthIsDifferentFromCreditsLength() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](0);

        CreditsManagerPolygon.ExternalCall memory externalCall =
            CreditsManagerPolygon.ExternalCall({target: address(this), selector: bytes4(0), data: bytes(""), expiresAt: 0, salt: bytes32(0)});

        bytes memory customExternalCallSignature = bytes("");

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0,
            maxCreditedValue: 0
        });

        vm.expectRevert(CreditsManagerPolygon.InvalidCreditsSignaturesLength.selector);
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenMaxCreditedValueZero() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        CreditsManagerPolygon.ExternalCall memory externalCall =
            CreditsManagerPolygon.ExternalCall({target: address(this), selector: bytes4(0), data: bytes(""), expiresAt: 0, salt: bytes32(0)});

        bytes memory customExternalCallSignature = bytes("");

        CreditsManagerPolygon.UseCreditsArgs memory args = CreditsManagerPolygon.UseCreditsArgs({
            credits: credits,
            creditsSignatures: creditsSignatures,
            externalCall: externalCall,
            customExternalCallSignature: customExternalCallSignature,
            maxUncreditedValue: 0,
            maxCreditedValue: 0
        });

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.MaxCreditedValueZero.selector));
        creditsManager.useCredits(args);
    }

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

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid + 1, address(creditsManager), externalCall)));

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
            abi.encodeWithSelector(CreditsManagerPolygon.InvalidCustomExternalCallSignature.selector, 0xeCc32Fcec42A961891851b4956374578C918Bc79)
        );
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenNoManaWasTransferred() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 0);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

    function test_useCredits_RevertsWhenCreditDoesNotHaveEnoughValue() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 0, expiresAt: 0, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.CreditExpired.selector, keccak256(creditsSignatures[0])));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCreditECDSAInvalidSignatureLength() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid + 1, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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
                CreditsManagerPolygon.InvalidSignature.selector, keccak256(creditsSignatures[0]), 0xcc9A69fee0faf31e970174cFc1FA3075d15eA28C
            )
        );
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenMaxCreditedValueExceeded() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 101 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 51 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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
        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));
        args.customExternalCallSignature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.MaxManaCreditedPerHourExceeded.selector, 49 ether, 51 ether));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenExecuteCallIsReused() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 200 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 51 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        vm.expectRevert(
            abi.encodeWithSelector(CreditsManagerPolygon.UsedCustomExternalCallSignature.selector, keccak256(customExternalCallSignature))
        );
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenUserIsDenied() public {
        vm.prank(denier);
        creditsManager.denyUser(address(this));

        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        vm.prank(owner);
        creditsManager.revokeCredit(keccak256(creditsSignatures[0]));

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.RevokedCredit.selector, keccak256(creditsSignatures[0])));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenCreditedValueIsZero() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        creditsManager.useCredits(args);

        externalCall.salt = bytes32(uint256(1));
        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));
        args.customExternalCallSignature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(CreditsManagerPolygon.CreditedValueZero.selector));
        creditsManager.useCredits(args);
    }

    function test_useCredits_RevertsWhenMaxUncreditedValueIsExceeded() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 50 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

    function test_useCredits_Success() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 100 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        assertEq(creditsManager.spentValue(keccak256(creditsSignatures[0])), 0);

        vm.expectEmit(address(creditsManager));
        emit CreditUsed(keccak256(creditsSignatures[0]), credits[0], 100 ether);
        vm.expectEmit(address(creditsManager));
        emit CreditsUsed(100 ether, 100 ether);
        creditsManager.useCredits(args);

        assertEq(creditsManager.spentValue(keccak256(creditsSignatures[0])), 100 ether);

        assertEq(IERC20(mana).balanceOf(address(this)), callerBalanceBefore);
        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 100 ether);
        assertEq(IERC20(mana).balanceOf(address(externalCallTarget)), externalCallTargetBalanceBefore + 100 ether);
    }

    function test_useCredits_Success_MaxManaCreditedPerHourIsResetAfterHour() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](1);

        credits[0] = CreditsManagerPolygon.Credit({value: 200 ether, expiresAt: type(uint256).max, salt: bytes32(0)});

        bytes[] memory creditsSignatures = new bytes[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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

        assertEq(creditsManager.spentValue(keccak256(creditsSignatures[0])), 0);

        vm.expectEmit(address(creditsManager));
        emit CreditUsed(keccak256(creditsSignatures[0]), credits[0], 100 ether);
        vm.expectEmit(address(creditsManager));
        emit CreditsUsed(100 ether, 100 ether);
        creditsManager.useCredits(args);

        assertEq(creditsManager.spentValue(keccak256(creditsSignatures[0])), 100 ether);

        assertEq(IERC20(mana).balanceOf(address(this)), callerBalanceBefore);
        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 100 ether);
        assertEq(IERC20(mana).balanceOf(address(externalCallTarget)), externalCallTargetBalanceBefore + 100 ether);

        externalCall.salt = bytes32(uint256(1));
        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));
        args.customExternalCallSignature = abi.encodePacked(r, s, v);

        vm.warp(block.timestamp + 1 hours);

        assertEq(creditsManager.spentValue(keccak256(creditsSignatures[0])), 100 ether);

        creditsManager.useCredits(args);

        assertEq(creditsManager.spentValue(keccak256(creditsSignatures[0])), 200 ether);

        assertEq(IERC20(mana).balanceOf(address(this)), callerBalanceBefore);
        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 200 ether);
        assertEq(IERC20(mana).balanceOf(address(externalCallTarget)), externalCallTargetBalanceBefore + 200 ether);
    }

    function test_useCredits_Success_TwoCredits() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](2);

        credits[0] = CreditsManagerPolygon.Credit({value: 50 ether, expiresAt: type(uint256).max, salt: bytes32(0)});
        credits[1] = CreditsManagerPolygon.Credit({value: 50 ether, expiresAt: type(uint256).max, salt: bytes32(uint256(1))});

        bytes[] memory creditsSignatures = new bytes[](2);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        (v, r, s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[1])));

        creditsSignatures[1] = abi.encodePacked(r, s, v);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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
        assertEq(creditsManager.spentValue(keccak256(creditsSignatures[1])), 0);

        uint256 callerBalanceBefore = IERC20(mana).balanceOf(address(this));
        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));
        uint256 externalCallTargetBalanceBefore = IERC20(mana).balanceOf(address(externalCallTarget));

        vm.expectEmit(address(creditsManager));
        emit CreditUsed(keccak256(creditsSignatures[0]), credits[0], 50 ether);
        vm.expectEmit(address(creditsManager));
        emit CreditUsed(keccak256(creditsSignatures[1]), credits[1], 50 ether);
        vm.expectEmit(address(creditsManager));
        emit CreditsUsed(100 ether, 100 ether);
        creditsManager.useCredits(args);

        assertEq(creditsManager.spentValue(keccak256(creditsSignatures[0])), 50 ether);
        assertEq(creditsManager.spentValue(keccak256(creditsSignatures[1])), 50 ether);

        assertEq(IERC20(mana).balanceOf(address(this)), callerBalanceBefore);
        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 100 ether);
        assertEq(IERC20(mana).balanceOf(address(externalCallTarget)), externalCallTargetBalanceBefore + 100 ether);
    }

    function test_useCredits_Success_TwoCredits_WithUncreditedValue() public {
        CreditsManagerPolygon.Credit[] memory credits = new CreditsManagerPolygon.Credit[](2);

        credits[0] = CreditsManagerPolygon.Credit({value: 50 ether, expiresAt: type(uint256).max, salt: bytes32(0)});
        credits[1] = CreditsManagerPolygon.Credit({value: 25 ether, expiresAt: type(uint256).max, salt: bytes32(uint256(1))});

        bytes[] memory creditsSignatures = new bytes[](2);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[0])));

        creditsSignatures[0] = abi.encodePacked(r, s, v);

        (v, r, s) = vm.sign(signerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), credits[1])));

        creditsSignatures[1] = abi.encodePacked(r, s, v);

        MockExternalCallTarget externalCallTarget = new MockExternalCallTarget(creditsManager, IERC20(mana), 100 ether);

        CreditsManagerPolygon.ExternalCall memory externalCall = CreditsManagerPolygon.ExternalCall({
            target: address(externalCallTarget),
            selector: externalCallTarget.someFunction.selector,
            data: bytes(""),
            expiresAt: type(uint256).max,
            salt: bytes32(0)
        });

        externalCall.data = abi.encode(bytes32(uint256(0)), uint256(1), uint256(2));

        (v, r, s) = vm.sign(customExternalCallSignerPk, keccak256(abi.encode(address(this), block.chainid, address(creditsManager), externalCall)));

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
        assertEq(creditsManager.spentValue(keccak256(creditsSignatures[1])), 0);

        uint256 callerBalanceBefore = IERC20(mana).balanceOf(address(this));
        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(address(creditsManager));
        uint256 externalCallTargetBalanceBefore = IERC20(mana).balanceOf(address(externalCallTarget));

        vm.expectEmit(address(creditsManager));
        emit CreditUsed(keccak256(creditsSignatures[0]), credits[0], 50 ether);
        vm.expectEmit(address(creditsManager));
        emit CreditUsed(keccak256(creditsSignatures[1]), credits[1], 25 ether);
        vm.expectEmit(address(creditsManager));
        emit CreditsUsed(100 ether, 75 ether);
        creditsManager.useCredits(args);

        assertEq(creditsManager.spentValue(keccak256(creditsSignatures[0])), 50 ether);
        assertEq(creditsManager.spentValue(keccak256(creditsSignatures[1])), 25 ether);

        assertEq(IERC20(mana).balanceOf(address(this)), callerBalanceBefore - 25 ether);
        assertEq(IERC20(mana).balanceOf(address(creditsManager)), creditsManagerBalanceBefore - 75 ether);
        assertEq(IERC20(mana).balanceOf(address(externalCallTarget)), externalCallTargetBalanceBefore + 100 ether);
    }
}
