// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {ERC1271WalletMock, ERC1271MaliciousMock} from "@openzeppelin/contracts/mocks/ERC1271WalletMock.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Marketplace} from "src/marketplace/Marketplace.sol";
import {MockExternalChecks} from "src/mocks/MockExternalChecks.sol";
import {EIP712} from "src/common/EIP712.sol";

// Import the malicious contract from the coupon tests
contract MaliciousContractWithCorrectMagicValue {
    function isValidSignature(bytes32, bytes memory) external pure returns (bytes4) {
        // Return the correct ERC1271 magic value (isValidSignature function selector)
        return 0x1626ba7e;
    }
}

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

    function test_CanSendAnEmptyArrayOfTrades() public {
        MarketplaceHarness.Trade[] memory trades;

        vm.prank(other);
        marketplace.cancelSignature(trades);
    }


    function test_EmitSignatureCancelledEvent() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signature = signTrade(trades[0]);

        // Compute the digest before the prank so the eip712TradeHash() call doesn't consume it.
        bytes32 orderHash = marketplace.eip712TradeHash(trades[0]);

        vm.prank(signer.addr);
        vm.expectEmit(address(marketplace));
        emit SignatureCancelled(signer.addr, orderHash);
        marketplace.cancelSignature(trades);
    }

    function test_CancelledSignaturesReturnsTrueForTheCancelledSignature() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signature = signTrade(trades[0]);

        bytes32 hashedSignature = marketplace.eip712TradeHash(trades[0]);
        bytes32 cancellationKey = keccak256(abi.encode(signer.addr, hashedSignature));

        assertEq(marketplace.cancelledSignatures(cancellationKey), false);

        vm.prank(signer.addr);
        marketplace.cancelSignature(trades);

        assertEq(marketplace.cancelledSignatures(cancellationKey), true);
    }

    function test_CanCancelTheSameSignatureMultipleTimes() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        trades[0].signature = signTrade(trades[0]);

        bytes32 hashedSignature = marketplace.eip712TradeHash(trades[0]);
        bytes32 cancellationKey = keccak256(abi.encode(signer.addr, hashedSignature));

        assertEq(marketplace.cancelledSignatures(cancellationKey), false);

        for (uint256 i = 0; i < 10; i++) {
            vm.prank(signer.addr);
            marketplace.cancelSignature(trades);

            assertEq(marketplace.cancelledSignatures(cancellationKey), true);
        }
    }

    function test_CanCancelMultipleSignaturesInOneCall() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](10);

        for (uint256 i = 0; i < trades.length; i++) {
            trades[i].checks.salt = bytes32(i);
            trades[i].signature = signTrade(trades[i]);

            bytes32 hashedSignature = marketplace.eip712TradeHash(trades[i]);
            bytes32 cancellationKey = keccak256(abi.encode(signer.addr, hashedSignature));
            assertEq(marketplace.cancelledSignatures(cancellationKey), false);
        }

        vm.prank(signer.addr);
        marketplace.cancelSignature(trades);

        for (uint256 i = 0; i < trades.length; i++) {
            bytes32 hashedSignature = marketplace.eip712TradeHash(trades[i]);
            bytes32 cancellationKey = keccak256(abi.encode(signer.addr, hashedSignature));
            assertEq(marketplace.cancelledSignatures(cancellationKey), true);
        }
    }



    function test_SupportsERC1271SignatureVerification() public {
        ERC1271WalletMock contractWallet = new ERC1271WalletMock(signer.addr);

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        // Set the signer to the contract wallet
        trades[0].signer = address(contractWallet);
        
        // Create a signature for the contract wallet (not the regular signer)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.privateKey, marketplace.eip712TradeHash(trades[0]));
        trades[0].signature = abi.encodePacked(r, s, v);

        vm.prank(address(contractWallet));
        marketplace.cancelSignature(trades);
    }

    function test_AnyoneCanCancelAnySignature() public {
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);
        trades[0].signature = signTrade(trades[0]);

        bytes32 hashedSignature = marketplace.eip712TradeHash(trades[0]);
        bytes32 cancellationKey = keccak256(abi.encode(other, hashedSignature));

        assertEq(marketplace.cancelledSignatures(cancellationKey), false);

        // Anyone can cancel any signature (DoS prevention)
        vm.prank(other);
        marketplace.cancelSignature(trades);

        assertEq(marketplace.cancelledSignatures(cancellationKey), true);
    }

    function test_CancelSignatureByNonSignerDoesNotPreventThirdPartyFromAccepting() public {
        // Create a third party who will accept the trade
        address thirdParty = makeAddr("thirdParty");
        
        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);
        trades[0].signer = signer.addr;
        trades[0].checks.uses = 1; // Allow the signature to be used once
        trades[0].checks.expiration = block.timestamp + 1; // Set expiration to future
        trades[0].signature = signTrade(trades[0]);

        bytes32 hashedSignature = marketplace.eip712TradeHash(trades[0]);
        bytes32 signerCancellationKey = keccak256(abi.encode(signer.addr, hashedSignature));
        bytes32 otherCancellationKey = keccak256(abi.encode(other, hashedSignature));
        bytes32 thirdPartyCancellationKey = keccak256(abi.encode(thirdParty, hashedSignature));

        // Initially, no cancellations exist
        assertEq(marketplace.cancelledSignatures(signerCancellationKey), false);
        assertEq(marketplace.cancelledSignatures(otherCancellationKey), false);
        assertEq(marketplace.cancelledSignatures(thirdPartyCancellationKey), false);

        // Someone else cancels the signature (they didn't create it)
        vm.prank(other);
        marketplace.cancelSignature(trades);

        // The cancellation is tied to 'other', not the original signer or third party
        assertEq(marketplace.cancelledSignatures(signerCancellationKey), false);
        assertEq(marketplace.cancelledSignatures(otherCancellationKey), true);
        assertEq(marketplace.cancelledSignatures(thirdPartyCancellationKey), false);

        // A third party can still accept the trade successfully
        // This demonstrates that cancellations are caller-specific, not signature-specific
        vm.prank(thirdParty);
        marketplace.accept(trades);

        // Verify the trade was accepted (no revert means success)
        // The cancellation by 'other' doesn't prevent 'thirdParty' from accepting the trade
        // This shows the DoS protection works correctly - only the caller's cancellation affects them
    }

    function test_MaliciousContractCanReuseValidSignatureForSameTradeAndConsumeUses() public {
        // Deploy a malicious contract that implements ERC1271
        MaliciousContractWithCorrectMagicValue maliciousContract = new MaliciousContractWithCorrectMagicValue();
        
        // Create a legitimate trade with 1 use, signed by the real user
        MarketplaceHarness.Trade memory legitimateTrade;
        legitimateTrade.checks.expiration = block.timestamp + 1;
        legitimateTrade.checks.uses = 1;
        legitimateTrade.signature = signTrade(legitimateTrade);
        
        // Create the EXACT same trade (same parameters) but the malicious contract will use it
        // The malicious contract can reuse the valid signature for the same trade
        MarketplaceHarness.Trade memory maliciousTrade = legitimateTrade; // Exact same trade
        maliciousTrade.signer = address(maliciousContract);
        
        // Initially, the signature has 0 uses
        bytes32 hashedSignature = keccak256(abi.encode(signer.addr, marketplace.eip712TradeHash(legitimateTrade)));
        bytes32 hashedMaliciousSignature = keccak256(abi.encode(address(maliciousContract), marketplace.eip712TradeHash(maliciousTrade)));
        assertNotEq(hashedSignature, hashedMaliciousSignature);
        assertEq(legitimateTrade.signature, maliciousTrade.signature);
        assertEq(marketplace.signatureUses(hashedSignature), 0);
        assertEq(marketplace.signatureUses(hashedMaliciousSignature), 0);
        
        // The malicious contract uses the signature for the same trade
        // This should succeed because the signature is valid and the malicious contract
        // can bypass signature verification by implementing ERC1271
        MarketplaceHarness.Trade[] memory maliciousTrades = new MarketplaceHarness.Trade[](1);
        maliciousTrades[0] = maliciousTrade;
        
        vm.prank(address(maliciousContract));
        marketplace.accept(maliciousTrades);
        
        // The signature use count is now 1 for the malicious trade
        assertEq(marketplace.signatureUses(hashedSignature), 0);
        assertEq(marketplace.signatureUses(hashedMaliciousSignature), 1);
        
        MarketplaceHarness.Trade[] memory legitimateTrades = new MarketplaceHarness.Trade[](1);
        legitimateTrade.signer = signer.addr;
        legitimateTrades[0] = legitimateTrade;
        
        vm.prank(signer.addr);
        marketplace.accept(legitimateTrades);

        // The signature use count is now 1 for the both trades
        assertEq(marketplace.signatureUses(hashedSignature), 1);
        assertEq(marketplace.signatureUses(hashedMaliciousSignature), 1);
    }

}

contract AcceptTests is MarketplaceTests {
    event Traded(address indexed _caller, bytes32 indexed _signature, bytes32 indexed _tradeDigest, MarketplaceHarness.Trade _trade);

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
        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(signer.addr);
        marketplace.cancelSignature(trades);

        vm.expectRevert(UsingCancelledSignature.selector);
        vm.prank(signer.addr);
        marketplace.accept(trades);
    }

    function test_RevertsIfTheTradeHasBeenUsed() public {
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

        bytes32 tradeDigest = marketplace.eip712TradeHash(trades[0]);

        vm.prank(other);
        vm.expectEmit(address(marketplace));
        emit Traded(other, keccak256(trades[0].signature), tradeDigest, trades[0]);
        marketplace.accept(trades);
    }
}

/// @notice Regression tests for the signature-encoding malleability fix.
/// Pre-fix, `cancelledSignatures` and `signatureUses` were keyed on `keccak256(signature)`, so an
/// ERC-1271 / EIP-7702 wallet accepting alternate encodings of the same signature could bypass both;
/// now they are keyed on the signed EIP-712 digest, invariant across encodings. The signer here is a
/// contract wallet that accepts ANY signature bytes — the worst case for this bug.
contract CancellationMalleabilityFixTests is Test {
    MarketplaceHarness marketplace;
    MaliciousContractWithCorrectMagicValue wallet;
    VmSafe.Wallet signer;
    address attacker1;
    address attacker2;

    function setUp() public {
        marketplace = new MarketplaceHarness(address(this));
        wallet = new MaliciousContractWithCorrectMagicValue();
        signer = vm.createWallet("signer");
        attacker1 = makeAddr("attacker1");
        attacker2 = makeAddr("attacker2");
    }

    function _order(bytes32 salt) internal view returns (MarketplaceHarness.Trade memory t) {
        t.signer = address(wallet);
        t.checks.uses = 1;
        t.checks.expiration = block.timestamp + 1000;
        t.checks.salt = salt;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.privateKey, marketplace.eip712TradeHash(t));
        t.signature = abi.encodePacked(r, s, v);
    }

    // A different byte-encoding of the "same" signature. The wallet accepts it just like the original.
    function _variant(bytes memory sig) internal pure returns (bytes memory) {
        return abi.encodePacked(sig, hex"00");
    }

    function _arr(MarketplaceHarness.Trade memory t) internal pure returns (MarketplaceHarness.Trade[] memory a) {
        a = new MarketplaceHarness.Trade[](1);
        a[0] = t;
    }

    /// A cancelled order cannot be re-executed by submitting a different signature encoding.
    function test_cancelledOrder_cannotBeReExecutedWithADifferentEncoding() public {
        MarketplaceHarness.Trade memory t = _order(keccak256("A"));

        // sanity: the variant is a genuinely different byte-string that the wallet still accepts.
        assertTrue(keccak256(t.signature) != keccak256(_variant(t.signature)));

        // The signer (the wallet) cancels the order.
        vm.prank(address(wallet));
        marketplace.cancelSignature(_arr(t));

        // An attacker re-submits the SAME order with a DIFFERENT signature encoding.
        t.signature = _variant(t.signature);
        vm.prank(attacker1);
        vm.expectRevert(abi.encodeWithSignature("UsingCancelledSignature()"));
        marketplace.accept(_arr(t));
    }

    /// A single-use order that was already accepted cannot be reused via a different encoding.
    function test_singleUseOrder_cannotBeReusedWithADifferentEncoding() public {
        MarketplaceHarness.Trade memory t = _order(keccak256("B"));

        // First (legitimate) use consumes the single allowed use.
        vm.prank(attacker1);
        marketplace.accept(_arr(t));

        // Replay the same order with a different encoding and a different caller.
        t.signature = _variant(t.signature);
        vm.prank(attacker2);
        vm.expectRevert(abi.encodeWithSignature("SignatureOveruse()"));
        marketplace.accept(_arr(t));
    }

    /// Baseline: cancellation still blocks the canonical encoding (held before and after the fix).
    function test_baseline_cancellationBlocksTheCanonicalEncoding() public {
        MarketplaceHarness.Trade memory t = _order(keccak256("C"));
        vm.prank(address(wallet));
        marketplace.cancelSignature(_arr(t));
        vm.prank(attacker1);
        vm.expectRevert(abi.encodeWithSignature("UsingCancelledSignature()"));
        marketplace.accept(_arr(t));
    }

    /// Regression: cancelling one order must not affect a different order.
    function test_cancellingOneOrderDoesNotBlockAnother() public {
        MarketplaceHarness.Trade memory a = _order(keccak256("A2"));
        MarketplaceHarness.Trade memory b = _order(keccak256("B2"));
        vm.prank(address(wallet));
        marketplace.cancelSignature(_arr(a));
        vm.prank(attacker1);
        marketplace.accept(_arr(b)); // must NOT revert
    }

    /// Off-chain correlation: two fills of the same order with different signature encodings emit the SAME
    /// `_tradeDigest` topic (the stable, malleability-proof identifier) while the legacy `_signature` topic
    /// differs per encoding — pinning down why indexers must key on the digest, not on keccak256(signature).
    function test_tradedEventEmitsTheSameTradeDigestAcrossSignatureEncodings() public {
        MarketplaceHarness.Trade memory t = _order(keccak256("D"));
        t.checks.uses = 2; // allow two fills; the wallet signer accepts any signature bytes.

        vm.recordLogs();

        vm.prank(attacker1);
        marketplace.accept(_arr(t));

        // Same order, different (still accepted) signature encoding, different caller.
        t.signature = _variant(t.signature);
        vm.prank(attacker2);
        marketplace.accept(_arr(t));

        VmSafe.Log[] memory logs = vm.getRecordedLogs();

        // The harness marketplace emits a single event per accept: Traded.
        bytes32[2] memory digestTopics;
        bytes32[2] memory signatureTopics;
        uint256 found;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(marketplace)) {
                digestTopics[found] = logs[i].topics[3];
                signatureTopics[found] = logs[i].topics[2];
                found++;
            }
        }

        assertEq(found, 2);
        // The digest topic is invariant across encodings and equals the signed digest...
        assertEq(digestTopics[0], digestTopics[1]);
        assertEq(digestTopics[0], marketplace.eip712TradeHash(t));
        // ...while the raw-signature-hash topic varies with the encoding.
        assertTrue(signatureTopics[0] != signatureTopics[1]);
    }
}


