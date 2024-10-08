// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {ERC1271WalletMock} from "@openzeppelin/contracts/mocks/ERC1271WalletMock.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Marketplace} from "src/marketplace/Marketplace.sol";
import {MockExternalChecks} from "src/mocks/MockExternalChecks.sol";
import {EIP712} from "src/common/EIP712.sol";

contract MarketplaceHarness is Marketplace {
    constructor(address _owner) Ownable(_owner) EIP712("Marketplace", "1.0.0") {}

    function eip712Name() external view returns (string memory) {
        return _EIP712Name();
    }

    function eip712Version() external view returns (string memory) {
        return _EIP712Version();
    }

    function eip712TradeHash(Trade calldata _trade) external view returns (bytes32) {
        return _hashTypedDataV4(_hashTrade(_trade));
    }

    function _modifyTrade(Trade memory _trade) internal pure override {}

    function _transferAsset(Asset memory _asset, address _from, address _signer, address _caller) internal pure override {
        // do nothing
    }
}

abstract contract MarketplaceTests is Test {
    address owner;
    address other;

    MarketplaceHarness marketplace;

    VmSafe.Wallet signer;

    error OwnableUnauthorizedAccount(address account);

    function setUp() public virtual {
        owner = vm.addr(0x1);
        other = vm.addr(0x2);
        marketplace = new MarketplaceHarness(owner);
        signer = vm.createWallet("signer");
    }

    function signTrade(MarketplaceHarness.Trade memory _trade) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.privateKey, marketplace.eip712TradeHash(_trade));
        return abi.encodePacked(r, s, v);
    }
}

contract SetUpTests is MarketplaceTests {
    function test_SetUpState() public view {
        assertEq(marketplace.owner(), owner);
        assertEq(marketplace.eip712Name(), "Marketplace");
        assertEq(marketplace.eip712Version(), "1.0.0");
    }
}

contract PauseTests is MarketplaceTests {
    event Paused(address account);

    error EnforcedPause();

    function test_RevertsIfNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, other));
        marketplace.pause();
    }

    function test_RevertsIfAlreadyPaused() public {
        vm.prank(owner);
        marketplace.pause();
        vm.prank(owner);
        vm.expectRevert(EnforcedPause.selector);
        marketplace.pause();
    }

    function test_EmitPausedEvent() public {
        vm.prank(owner);
        vm.expectEmit(address(marketplace));
        emit Paused(owner);
        marketplace.pause();
    }

    function test_PausedReturnsTrue() public {
        vm.prank(owner);
        marketplace.pause();
        assertEq(marketplace.paused(), true);
    }
}

contract UnpauseTests is MarketplaceTests {
    event Unpaused(address account);

    error ExpectedPause();

    function setUp() public override {
        super.setUp();
        vm.prank(owner);
        marketplace.pause();
    }

    function test_RevertsIfNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, other));
        marketplace.unpause();
    }

    function test_RevertsIfNotPaused() public {
        vm.prank(owner);
        marketplace.unpause();
        vm.prank(owner);
        vm.expectRevert(ExpectedPause.selector);
        marketplace.unpause();
    }

    function test_EmitUnpausedEvent() public {
        vm.prank(owner);
        vm.expectEmit(address(marketplace));
        emit Unpaused(owner);
        marketplace.unpause();
    }

    function test_PausedReturnsFalse() public {
        vm.prank(owner);
        marketplace.unpause();
        assertEq(marketplace.paused(), false);
    }
}

contract IncreaseContractSignatureIndexTests is MarketplaceTests {
    event ContractSignatureIndexIncreased(address indexed _caller, uint256 indexed _newValue);

    function test_RevertsIfNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, other));
        marketplace.increaseContractSignatureIndex();
    }

    function test_EmitContractSignatureIndexIncreasedEvent() public {
        vm.prank(owner);
        vm.expectEmit(address(marketplace));
        emit ContractSignatureIndexIncreased(owner, 1);
        marketplace.increaseContractSignatureIndex();
    }

    function test_ContractSignatureIndexReturnsTheCurrentValue() public {
        assertEq(marketplace.contractSignatureIndex(), 0);
        vm.prank(owner);
        marketplace.increaseContractSignatureIndex();
        assertEq(marketplace.contractSignatureIndex(), 1);
    }

    function test_IncreasesTheContractSignatureIndexByOne() public {
        for (uint256 i = 0; i < 10; i++) {
            assertEq(marketplace.contractSignatureIndex(), i);
            vm.prank(owner);
            vm.expectEmit(address(marketplace));
            emit ContractSignatureIndexIncreased(owner, i + 1);
            marketplace.increaseContractSignatureIndex();
            assertEq(marketplace.contractSignatureIndex(), i + 1);
        }
    }
}

contract IncreaseSignerSignatureIndexTests is MarketplaceTests {
    event SignerSignatureIndexIncreased(address indexed _caller, uint256 indexed _newValue);

    function test_EmitSignerSignatureIndexIncreasedEvent() public {
        vm.prank(other);
        vm.expectEmit(address(marketplace));
        emit SignerSignatureIndexIncreased(other, 1);
        marketplace.increaseSignerSignatureIndex();
    }

    function test_SignerSignatureIndexReturnsTheCurrentValue() public {
        assertEq(marketplace.signerSignatureIndex(other), 0);
        vm.prank(other);
        marketplace.increaseSignerSignatureIndex();
        assertEq(marketplace.signerSignatureIndex(other), 1);
    }

    function test_IncreasesTheSignerSignatureIndexByOne() public {
        for (uint256 i = 0; i < 10; i++) {
            assertEq(marketplace.signerSignatureIndex(other), i);
            vm.prank(other);
            vm.expectEmit(address(marketplace));
            emit SignerSignatureIndexIncreased(other, i + 1);
            marketplace.increaseSignerSignatureIndex();
            assertEq(marketplace.signerSignatureIndex(other), i + 1);
        }
    }
}

contract CancelSignatureTests is MarketplaceTests {
    event SignatureCancelled(address indexed _caller, bytes32 indexed _signature);

    error InvalidSignature();

    function test_CanSendAnEmptyArrayOfTrades() public {
        MarketplaceHarness.Trade[] memory trades;

        vm.prank(other);
        marketplace.cancelSignature(trades);
    }

    function test_RevertsIfTheSignerIsNotTheCaller() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        vm.expectRevert(InvalidSignature.selector);
        marketplace.cancelSignature(trades);
    }

    function test_EmitSignatureCancelledEvent() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signature = signTrade(trades[0]);

        vm.prank(signer.addr);
        vm.expectEmit(address(marketplace));
        emit SignatureCancelled(signer.addr, keccak256(trades[0].signature));
        marketplace.cancelSignature(trades);
    }

    function test_CancelledSignaturesReturnsTrueForTheCancelledSignature() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signature = signTrade(trades[0]);

        assertEq(marketplace.cancelledSignatures(keccak256(trades[0].signature)), false);

        vm.prank(signer.addr);
        marketplace.cancelSignature(trades);

        assertEq(marketplace.cancelledSignatures(keccak256(trades[0].signature)), true);
    }

    function test_CanCancelTheSameSignatureMultipleTimes() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signature = signTrade(trades[0]);

        assertEq(marketplace.cancelledSignatures(keccak256(trades[0].signature)), false);

        for (uint256 i = 0; i < 10; i++) {
            vm.prank(signer.addr);
            marketplace.cancelSignature(trades);

            assertEq(marketplace.cancelledSignatures(keccak256(trades[0].signature)), true);
        }
    }

    function test_CanCancelMultipleSignaturesInOneCall() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](10);

        for (uint256 i = 0; i < trades.length; i++) {
            trades[i].checks.salt = bytes32(i);
            trades[i].signature = signTrade(trades[i]);

            assertEq(marketplace.cancelledSignatures(keccak256(trades[i].signature)), false);
        }

        vm.prank(signer.addr);
        marketplace.cancelSignature(trades);

        for (uint256 i = 0; i < trades.length; i++) {
            assertEq(marketplace.cancelledSignatures(keccak256(trades[i].signature)), true);
        }
    }

    function test_RevertsIfOneOfTheMultipleTradesSignaturesCancelledIsInvalid() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](10);

        for (uint256 i = 0; i < trades.length; i++) {
            trades[i].checks.salt = bytes32(i);
            trades[i].signature = signTrade(trades[i]);
        }

        trades[5].signature = "0xInvalid";

        vm.prank(signer.addr);
        vm.expectRevert(InvalidSignature.selector);
        marketplace.cancelSignature(trades);
    }

    function test_RevertsIfERC1271SignatureVerificationFails() public {
        ERC1271WalletMock contractWallet = new ERC1271WalletMock(other);

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signature = signTrade(trades[0]);

        vm.prank(address(contractWallet));
        vm.expectRevert(InvalidSignature.selector);
        marketplace.cancelSignature(trades);
    }

    function test_SupportsERC1271SignatureVerification() public {
        ERC1271WalletMock contractWallet = new ERC1271WalletMock(signer.addr);

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signature = signTrade(trades[0]);

        vm.prank(address(contractWallet));
        marketplace.cancelSignature(trades);
    }
}

contract AcceptTests is MarketplaceTests {
    event Traded(address indexed _caller, bytes32 indexed _signature, MarketplaceHarness.Trade _trade);

    error UsedTradeId();
    error NotEffective();
    error InvalidContractSignatureIndex();
    error InvalidSignerSignatureIndex();
    error Expired();
    error NotAllowed();
    error ExternalChecksFailed();
    error UsingCancelledSignature();
    error SignatureOveruse();

    function test_CanSendAnEmptyArrayOfTrades() public {
        MarketplaceHarness.Trade[] memory trades;

        vm.prank(other);
        marketplace.accept(trades);
    }

    function test_RevertsIfTheSignatureHasBeenCancelled() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signature = signTrade(trades[0]);

        vm.prank(signer.addr);
        marketplace.cancelSignature(trades);

        vm.prank(other);
        vm.expectRevert(UsingCancelledSignature.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfTheSignatureHasBeenUsed() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signer = signer.addr;
        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        marketplace.accept(trades);

        vm.prank(other);
        vm.expectRevert(UsedTradeId.selector);
        marketplace.accept(trades);
    }

    function test_SignatureWithTenUsesCanBeUsedTenTimes() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signer = signer.addr;
        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 10;
        trades[0].signature = signTrade(trades[0]);

        for (uint256 i = 0; i < trades[0].checks.uses; i++) {
            vm.prank(other);
            marketplace.accept(trades);
        }

        vm.prank(other);
        vm.expectRevert(UsedTradeId.selector);
        marketplace.accept(trades);
    }

    function test_TradeIdIsStoredAfterAllUsesConsumed() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signer = signer.addr;
        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 3;
        trades[0].signature = signTrade(trades[0]);

        for (uint256 i = 0; i < trades[0].checks.uses; i++) {
            assertEq(marketplace.usedTradeIds(marketplace.getTradeId(trades[0], other)), false);

            vm.prank(other);
            marketplace.accept(trades);
        }

        assertEq(marketplace.usedTradeIds(marketplace.getTradeId(trades[0], other)), true);
    }

    function test_RevertsIfTradeIdHasBeenUsed() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signer = signer.addr;
        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        marketplace.accept(trades);

        trades[0].checks.uses = 2;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        vm.expectRevert(UsedTradeId.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfTradeIsNotEffectiveYet() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.effective = block.timestamp + 1;
        trades[0].checks.uses = 1;

        vm.prank(other);
        vm.expectRevert(NotEffective.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfContractSignatureIndexIsInvalid() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.contractSignatureIndex = 1;
        trades[0].checks.uses = 1;

        vm.prank(other);
        vm.expectRevert(InvalidContractSignatureIndex.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfSignerSignatureIndexIsInvalid() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.signerSignatureIndex = 1;
        trades[0].checks.uses = 1;

        vm.prank(other);
        vm.expectRevert(InvalidSignerSignatureIndex.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfTradeHasExpired() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp - 1;
        trades[0].checks.uses = 1;

        vm.prank(other);
        vm.expectRevert(Expired.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfUsesIsZero() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.uses = 0;

        vm.prank(other);
        vm.expectRevert(SignatureOveruse.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfCallerNotAllowed_NoProof() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;
        trades[0].checks.allowedRoot = 0x3760ed777a92c3c15784377c1323a9f14e6b22527504861052eae84c523e6940;

        vm.prank(0x0000000000000000000000000000000000000001);
        vm.expectRevert(NotAllowed.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfCallerNotAllowed_InvalidProof() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;
        trades[0].checks.allowedRoot = 0x3760ed777a92c3c15784377c1323a9f14e6b22527504861052eae84c523e6940;
        trades[0].checks.allowedProof = new bytes32[](3);
        trades[0].checks.allowedProof[0] = 0xb868bdfa8727775661e4ccf117824a175a33f8703d728c04488fbfffcafda9f9;
        trades[0].checks.allowedProof[1] = 0xc949c2dc5da2bd9a4f5ae27532dfbb3551487bed50825cd099ff5d0a8d613ab5;
        trades[0].checks.allowedProof[2] = 0x5c5f637d4c3416c9b00567ede8dd9714445a6b076030f6b49d7607beea171ec5;

        vm.prank(0x0000000000000000000000000000000000000002);
        vm.expectRevert(NotAllowed.selector);
        marketplace.accept(trades);
    }

    function test_CallerCanAcceptIfItIsInTheAllowedList() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;
        trades[0].checks.allowedRoot = 0x3760ed777a92c3c15784377c1323a9f14e6b22527504861052eae84c523e6940;
        trades[0].checks.allowedProof = new bytes32[](3);
        trades[0].checks.allowedProof[0] = 0xb868bdfa8727775661e4ccf117824a175a33f8703d728c04488fbfffcafda9f9;
        trades[0].checks.allowedProof[1] = 0xc949c2dc5da2bd9a4f5ae27532dfbb3551487bed50825cd099ff5d0a8d613ab5;
        trades[0].checks.allowedProof[2] = 0x5c5f637d4c3416c9b00567ede8dd9714445a6b076030f6b49d7607beea171ec5;
        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(0x0000000000000000000000000000000000000001);
        marketplace.accept(trades);
    }

    function test_CallerCanAcceptIfItIsInTheAllowedList_RootOfOneAddress() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;
        trades[0].checks.allowedRoot = 0xb5d9d894133a730aa651ef62d26b0ffa846233c74177a591a4a896adfda97d22;
        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(0x0000000000000000000000000000000000000002);
        vm.expectRevert(NotAllowed.selector);
        marketplace.accept(trades);

        vm.prank(0x0000000000000000000000000000000000000001);
        marketplace.accept(trades);
    }

    function test_RevertsIfBalanceOfRequiredExternalCheckFails() public {
        MockExternalChecks mockExternalChecks = new MockExternalChecks();

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;

        trades[0].checks.externalChecks = new MarketplaceHarness.ExternalCheck[](1);

        uint256 externalCheckValue = 1;

        trades[0].checks.externalChecks[0].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[0].selector = mockExternalChecks.balanceOf.selector;
        trades[0].checks.externalChecks[0].value = abi.encode(externalCheckValue);
        trades[0].checks.externalChecks[0].required = true;

        mockExternalChecks.setBalanceOfResult(0);

        vm.prank(other);
        vm.expectRevert(ExternalChecksFailed.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfOwnerOfRequiredExternalCheckFails() public {
        MockExternalChecks mockExternalChecks = new MockExternalChecks();

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;

        trades[0].checks.externalChecks = new MarketplaceHarness.ExternalCheck[](1);

        uint256 externalCheckValue = 1;

        trades[0].checks.externalChecks[0].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[0].selector = mockExternalChecks.ownerOf.selector;
        trades[0].checks.externalChecks[0].value = abi.encode(externalCheckValue);
        trades[0].checks.externalChecks[0].required = true;

        mockExternalChecks.setOwnerOfResult(signer.addr);

        vm.prank(other);
        vm.expectRevert(ExternalChecksFailed.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfCustomSelectorDoesNotExistOnCalledContract() public {
        MockExternalChecks mockExternalChecks = new MockExternalChecks();

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;

        trades[0].checks.externalChecks = new MarketplaceHarness.ExternalCheck[](1);

        trades[0].checks.externalChecks[0].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[0].selector = 0x215eea7f; // Random bytes4 selector.
        trades[0].checks.externalChecks[0].required = true;

        mockExternalChecks.setCustomCheckFunctionResult(true);

        vm.prank(other);
        vm.expectRevert(ExternalChecksFailed.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfCustomCheckFunctionRequiredExternalCheckFails() public {
        MockExternalChecks mockExternalChecks = new MockExternalChecks();

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;

        trades[0].checks.externalChecks = new MarketplaceHarness.ExternalCheck[](1);

        trades[0].checks.externalChecks[0].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[0].selector = mockExternalChecks.customCheckFunctionBytes.selector;
        trades[0].checks.externalChecks[0].required = true;

        mockExternalChecks.setCustomCheckFunctionResult(false);

        vm.prank(other);
        vm.expectRevert(ExternalChecksFailed.selector);
        marketplace.accept(trades);
    }

    function test_TradesWhenCustomExternalCheckPasses() public {
        MockExternalChecks mockExternalChecks = new MockExternalChecks();

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;

        trades[0].checks.externalChecks = new MarketplaceHarness.ExternalCheck[](1);

        trades[0].checks.externalChecks[0].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[0].selector = mockExternalChecks.customCheckFunctionBytes.selector;
        trades[0].checks.externalChecks[0].required = true;

        mockExternalChecks.setCustomCheckFunctionResult(true);

        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        marketplace.accept(trades);
    }

    function test_TradesWhenCustomExternalToFunctionThatAcceptsUint256InsteadOfBytesSucceeds() public {
        MockExternalChecks mockExternalChecks = new MockExternalChecks();

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;

        trades[0].checks.externalChecks = new MarketplaceHarness.ExternalCheck[](1);

        trades[0].checks.externalChecks[0].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[0].selector = mockExternalChecks.customCheckFunctionUint256.selector;
        trades[0].checks.externalChecks[0].required = true;

        mockExternalChecks.setCustomCheckFunctionResult(true);

        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        marketplace.accept(trades);
    }

    function test_RevertsIfProvidedBytesValueIsInvalidForTheExternalCheckCall() public {
        MockExternalChecks mockExternalChecks = new MockExternalChecks();

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;

        trades[0].checks.externalChecks = new MarketplaceHarness.ExternalCheck[](1);

        uint256 eternalCheckValue = 99;

        trades[0].checks.externalChecks[0].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[0].selector = mockExternalChecks.customCheckFunctionBytesExpects100.selector;
        trades[0].checks.externalChecks[0].required = true;
        trades[0].checks.externalChecks[0].value = abi.encode(eternalCheckValue);

        mockExternalChecks.setCustomCheckFunctionResult(true);

        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        vm.expectRevert(ExternalChecksFailed.selector);
        marketplace.accept(trades);
    }

    function test_TradesIfProvidedBytesValueIsValidForTheExternalCheckCall() public {
        MockExternalChecks mockExternalChecks = new MockExternalChecks();

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;

        trades[0].checks.externalChecks = new MarketplaceHarness.ExternalCheck[](1);

        uint256 eternalCheckValue = 100;

        trades[0].checks.externalChecks[0].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[0].selector = mockExternalChecks.customCheckFunctionBytesExpects100.selector;
        trades[0].checks.externalChecks[0].required = true;
        trades[0].checks.externalChecks[0].value = abi.encode(eternalCheckValue);

        mockExternalChecks.setCustomCheckFunctionResult(true);

        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        marketplace.accept(trades);
    }

    function test_RevertsIfCalledFunctionIsNotView() public {
        MockExternalChecks mockExternalChecks = new MockExternalChecks();

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;

        trades[0].checks.externalChecks = new MarketplaceHarness.ExternalCheck[](1);

        uint256 eternalCheckValue = 100;

        trades[0].checks.externalChecks[0].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[0].selector = mockExternalChecks.customCheckFunctionNotView.selector;
        trades[0].checks.externalChecks[0].required = true;
        trades[0].checks.externalChecks[0].value = abi.encode(eternalCheckValue);

        mockExternalChecks.setCustomCheckFunctionResult(true);

        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        vm.expectRevert(ExternalChecksFailed.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfOnly1Of2RequiredChecksPass() public {
        MockExternalChecks mockExternalChecks = new MockExternalChecks();

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;

        trades[0].checks.externalChecks = new MarketplaceHarness.ExternalCheck[](2);

        uint256 externalCheckValue = 1;

        trades[0].checks.externalChecks[0].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[0].selector = mockExternalChecks.balanceOf.selector;
        trades[0].checks.externalChecks[0].value = abi.encode(externalCheckValue);
        trades[0].checks.externalChecks[0].required = true;

        trades[0].checks.externalChecks[1].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[1].selector = mockExternalChecks.ownerOf.selector;
        trades[0].checks.externalChecks[1].value = abi.encode(externalCheckValue);
        trades[0].checks.externalChecks[1].required = true;

        mockExternalChecks.setBalanceOfResult(1); // pass
        mockExternalChecks.setOwnerOfResult(signer.addr); // fail

        vm.prank(other);
        vm.expectRevert(ExternalChecksFailed.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfOnlyTheRequiredCheckPassesButTheOptionalNot() public {
        MockExternalChecks mockExternalChecks = new MockExternalChecks();

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;

        trades[0].checks.externalChecks = new MarketplaceHarness.ExternalCheck[](2);

        uint256 externalCheckValue = 1;

        trades[0].checks.externalChecks[0].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[0].selector = mockExternalChecks.balanceOf.selector;
        trades[0].checks.externalChecks[0].value = abi.encode(externalCheckValue);
        trades[0].checks.externalChecks[0].required = true;

        trades[0].checks.externalChecks[1].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[1].selector = mockExternalChecks.ownerOf.selector;
        trades[0].checks.externalChecks[1].value = abi.encode(externalCheckValue);
        trades[0].checks.externalChecks[1].required = false;

        mockExternalChecks.setBalanceOfResult(1); // pass
        mockExternalChecks.setOwnerOfResult(signer.addr); // fail

        vm.prank(other);
        vm.expectRevert(ExternalChecksFailed.selector);
        marketplace.accept(trades);
    }

    function test_Only1OptionalCheckIsNeededToPass() public {
        MockExternalChecks mockExternalChecks = new MockExternalChecks();

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;

        trades[0].checks.externalChecks = new MarketplaceHarness.ExternalCheck[](2);

        uint256 externalCheckValue = 1;

        trades[0].checks.externalChecks[0].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[0].selector = mockExternalChecks.balanceOf.selector;
        trades[0].checks.externalChecks[0].value = abi.encode(externalCheckValue);
        trades[0].checks.externalChecks[0].required = false;

        trades[0].checks.externalChecks[1].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[1].selector = mockExternalChecks.ownerOf.selector;
        trades[0].checks.externalChecks[1].value = abi.encode(externalCheckValue);
        trades[0].checks.externalChecks[1].required = false;

        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        mockExternalChecks.setBalanceOfResult(1); // pass
        mockExternalChecks.setOwnerOfResult(signer.addr); // fail

        vm.prank(other);
        marketplace.accept(trades);
    }

    function test_AllRequiredChecksNeedToPass() public {
        MockExternalChecks mockExternalChecks = new MockExternalChecks();

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;

        trades[0].checks.externalChecks = new MarketplaceHarness.ExternalCheck[](2);

        uint256 externalCheckValue = 1;

        trades[0].checks.externalChecks[0].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[0].selector = mockExternalChecks.balanceOf.selector;
        trades[0].checks.externalChecks[0].value = abi.encode(externalCheckValue);
        trades[0].checks.externalChecks[0].required = true;

        trades[0].checks.externalChecks[1].contractAddress = address(mockExternalChecks);
        trades[0].checks.externalChecks[1].selector = mockExternalChecks.ownerOf.selector;
        trades[0].checks.externalChecks[1].value = abi.encode(externalCheckValue);
        trades[0].checks.externalChecks[1].required = true;

        mockExternalChecks.setBalanceOfResult(1); // pass
        mockExternalChecks.setOwnerOfResult(other); // pass

        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        marketplace.accept(trades);
    }

    function test_EmitTradedEvent() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.uses = 1;
        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        vm.expectEmit(address(marketplace));
        emit Traded(other, keccak256(trades[0].signature), trades[0]);
        marketplace.accept(trades);
    }
}
