// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, Vm} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";

import {CreditManager} from "src/credits/CreditManager.sol";
import {CollectionStoreStrategy} from "src/credits/strategies/CollectionStoreStrategy.sol";
import {MarketplaceStrategy} from "src/credits/strategies/MarketplaceStrategy.sol";
import {OffchainMarketplaceStrategy} from "src/credits/strategies/OffchainMarketplaceStrategy.sol";
import {ArbitraryCallStrategy} from "src/credits/strategies/ArbitraryCallStrategy.sol";
import {CreditManagerBase} from "src/credits/CreditManagerBase.sol";
import {ICollectionStore} from "src/credits/interfaces/ICollectionStore.sol";
import {IMarketplace} from "src/credits/interfaces/IMarketplace.sol";
import {IManaUsdRateProvider} from "src/credits/rates/interfaces/IManaUsdRateProvider.sol";
import {MarketplaceWithCouponManager} from "src/marketplace/MarketplaceWithCouponManager.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";

contract CreditManagerHarness is CreditManager {
    constructor(
        CollectionStoreStrategyInit memory _collectionStoreStrategyInit,
        MarketplaceStrategyInit memory _marketplaceStrategyInit,
        OffchainMarketplaceStrategyInit memory _offchainMarketplaceStrategyInit,
        ArbitraryCallStrategyInit memory _arbitraryCallStrategyInit,
        CreditManagerBaseInit memory _creditManagerBaseInit
    )
        CreditManager(
            _collectionStoreStrategyInit,
            _marketplaceStrategyInit,
            _offchainMarketplaceStrategyInit,
            _arbitraryCallStrategyInit,
            _creditManagerBaseInit
        )
    {}
}

contract CreditManagerTest is Test, IERC721Receiver {
    Addresses private addresses;

    uint256 landTokenId;

    struct Addresses {
        address mana;
        address marketplace;
        address landSeller;
        address land;
    }

    event CreditConsumed(address indexed _sender, CreditManagerHarness.Credit _credit);

    function setUp() public {
        uint256 mainnetFork = vm.createFork("https://rpc.decentraland.org/mainnet", 21855460); // Feb-16-2025 12:45:59 AM +UTC
        vm.selectFork(mainnetFork);

        addresses.mana = 0x0F5D2fB29fb7d3CFeE444a200298f468908cC942;
        addresses.marketplace = 0x8e5660b4Ab70168b5a6fEeA0e0315cb49c8Cd539;
        addresses.landSeller = 0x959e104E1a4dB6317fA58F8295F586e1A978c297;
        addresses.land = 0xF87E31492Faf9A91B02Ee0dEAAd50d51d56D5d4d;

        landTokenId = 55466025808112969544530061011378218467468;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function test_executeMarketplaceExecuteOrder_RevertsIfSecondarySalesAreNotAllowed() public {
        CreditManagerHarness.CollectionStoreStrategyInit memory collectionStoreStrategyInit;
        CreditManagerHarness.MarketplaceStrategyInit memory marketplaceStrategyInit;
        CreditManagerHarness.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit;
        CreditManagerHarness.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit;
        CreditManagerHarness.CreditManagerBaseInit memory creditManagerBaseInit;

        CreditManagerHarness creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );

        vm.expectRevert("Secondary sales are not allowed");
        creditManager.executeMarketplaceExecuteOrder(address(0), 0, 0, "", new CreditManagerHarness.Credit[](0));
    }

    function test_executeMarketplaceExecuteOrder_RevertsIfNoCreditsWereProvided() public {
        CreditManagerHarness.CollectionStoreStrategyInit memory collectionStoreStrategyInit;
        CreditManagerHarness.MarketplaceStrategyInit memory marketplaceStrategyInit;
        CreditManagerHarness.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit;
        CreditManagerHarness.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit;
        CreditManagerHarness.CreditManagerBaseInit memory creditManagerBaseInit;

        creditManagerBaseInit.secondarySalesAllowed = true;

        CreditManagerHarness creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );

        vm.expectRevert("No credits provided");
        creditManager.executeMarketplaceExecuteOrder(address(0), 0, 0, "", new CreditManagerHarness.Credit[](0));
    }

    function test_executeMarketplaceExecuteOrder_RevertsIfCreditIsExpired() public {
        CreditManagerHarness.CollectionStoreStrategyInit memory collectionStoreStrategyInit;
        CreditManagerHarness.MarketplaceStrategyInit memory marketplaceStrategyInit;
        CreditManagerHarness.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit;
        CreditManagerHarness.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit;
        CreditManagerHarness.CreditManagerBaseInit memory creditManagerBaseInit;

        creditManagerBaseInit.secondarySalesAllowed = true;

        CreditManagerHarness creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );

        vm.expectRevert("Credit has expired");
        creditManager.executeMarketplaceExecuteOrder(address(0), 0, 0, "", new CreditManagerHarness.Credit[](1));
    }

    function test_executeMarketplaceExecuteOrder_RevertsIfSignatureIsEmpty() public {
        CreditManagerHarness.CollectionStoreStrategyInit memory collectionStoreStrategyInit;
        CreditManagerHarness.MarketplaceStrategyInit memory marketplaceStrategyInit;
        CreditManagerHarness.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit;
        CreditManagerHarness.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit;
        CreditManagerHarness.CreditManagerBaseInit memory creditManagerBaseInit;

        creditManagerBaseInit.secondarySalesAllowed = true;

        CreditManagerHarness creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );

        CreditManagerHarness.Credit[] memory credits = new CreditManagerHarness.Credit[](1);
        credits[0].expiration = type(uint256).max;

        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureLength.selector, 0));
        creditManager.executeMarketplaceExecuteOrder(address(0), 0, 0, "", credits);
    }

    function test_executeMarketplaceExecuteOrder_RevertsIfSignatureIsInvalid() public {
        Vm.Wallet memory creditSigner = vm.createWallet("creditSigner");

        CreditManagerHarness.CollectionStoreStrategyInit memory collectionStoreStrategyInit;
        CreditManagerHarness.MarketplaceStrategyInit memory marketplaceStrategyInit;
        CreditManagerHarness.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit;
        CreditManagerHarness.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit;
        CreditManagerHarness.CreditManagerBaseInit memory creditManagerBaseInit;

        creditManagerBaseInit.secondarySalesAllowed = true;

        CreditManagerHarness creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );

        CreditManagerHarness.Credit[] memory credits = new CreditManagerHarness.Credit[](1);
        credits[0].expiration = type(uint256).max;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditSigner.privateKey, bytes32(0));
        credits[0].signature = abi.encodePacked(r, s, v);

        vm.expectRevert("Invalid credit signature");
        creditManager.executeMarketplaceExecuteOrder(address(0), 0, 0, "", credits);
    }

    function test_executeMarketplaceExecuteOrder_RevertsIfCreditHasAlreadyBeenSpent() public {
        Vm.Wallet memory creditSigner = vm.createWallet("creditSigner");

        CreditManagerHarness.CollectionStoreStrategyInit memory collectionStoreStrategyInit;
        CreditManagerHarness.MarketplaceStrategyInit memory marketplaceStrategyInit;
        CreditManagerHarness.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit;
        CreditManagerHarness.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit;
        CreditManagerHarness.CreditManagerBaseInit memory creditManagerBaseInit;

        creditManagerBaseInit.secondarySalesAllowed = true;

        creditManagerBaseInit.signer = creditSigner.addr;

        CreditManagerHarness creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );

        CreditManagerHarness.Credit[] memory credits = new CreditManagerHarness.Credit[](1);
        credits[0].expiration = type(uint256).max;
        bytes32 digest =
            keccak256(abi.encode(address(this), address(creditManager), block.chainid, credits[0].amount, credits[0].expiration, credits[0].salt));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditSigner.privateKey, digest);
        credits[0].signature = abi.encodePacked(r, s, v);

        vm.expectRevert("Credit has been spent");
        creditManager.executeMarketplaceExecuteOrder(address(0), 0, 0, "", credits);
    }

    function test_executeMarketplaceExecuteOrder_RevertsIfManaAddressIsZero() public {
        Vm.Wallet memory creditSigner = vm.createWallet("creditSigner");

        CreditManagerHarness.CollectionStoreStrategyInit memory collectionStoreStrategyInit;
        CreditManagerHarness.MarketplaceStrategyInit memory marketplaceStrategyInit;
        CreditManagerHarness.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit;
        CreditManagerHarness.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit;
        CreditManagerHarness.CreditManagerBaseInit memory creditManagerBaseInit;

        creditManagerBaseInit.secondarySalesAllowed = true;
        creditManagerBaseInit.signer = creditSigner.addr;

        CreditManagerHarness creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );

        CreditManagerHarness.Credit[] memory credits = new CreditManagerHarness.Credit[](1);
        credits[0].expiration = type(uint256).max;
        credits[0].amount = 1 ether;
        bytes32 digest =
            keccak256(abi.encode(address(this), address(creditManager), block.chainid, credits[0].amount, credits[0].expiration, credits[0].salt));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditSigner.privateKey, digest);
        credits[0].signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(Address.AddressEmptyCode.selector, address(0)));
        creditManager.executeMarketplaceExecuteOrder(address(0), 0, 0, "", credits);
    }

    function test_executeMarketplaceExecuteOrder_RevertsIfMarketplaceAddressIsZero() public {
        Vm.Wallet memory creditSigner = vm.createWallet("creditSigner");

        CreditManagerHarness.CollectionStoreStrategyInit memory collectionStoreStrategyInit;
        CreditManagerHarness.MarketplaceStrategyInit memory marketplaceStrategyInit;
        CreditManagerHarness.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit;
        CreditManagerHarness.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit;
        CreditManagerHarness.CreditManagerBaseInit memory creditManagerBaseInit;

        creditManagerBaseInit.secondarySalesAllowed = true;
        creditManagerBaseInit.signer = creditSigner.addr;
        creditManagerBaseInit.mana = IERC20(addresses.mana);

        CreditManagerHarness creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );

        CreditManagerHarness.Credit[] memory credits = new CreditManagerHarness.Credit[](1);
        credits[0].expiration = type(uint256).max;
        credits[0].amount = 1 ether;
        bytes32 digest =
            keccak256(abi.encode(address(this), address(creditManager), block.chainid, credits[0].amount, credits[0].expiration, credits[0].salt));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditSigner.privateKey, digest);
        credits[0].signature = abi.encodePacked(r, s, v);

        vm.expectRevert();
        creditManager.executeMarketplaceExecuteOrder(address(0), 0, 0, "", credits);
    }

    function test_executeMarketplaceExecuteOrder_RevertsIfTheProvidedAddressIsNotAContract() public {
        Vm.Wallet memory creditSigner = vm.createWallet("creditSigner");

        CreditManagerHarness.CollectionStoreStrategyInit memory collectionStoreStrategyInit;
        CreditManagerHarness.MarketplaceStrategyInit memory marketplaceStrategyInit;
        CreditManagerHarness.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit;
        CreditManagerHarness.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit;
        CreditManagerHarness.CreditManagerBaseInit memory creditManagerBaseInit;

        marketplaceStrategyInit.marketplace = IMarketplace(addresses.marketplace);

        creditManagerBaseInit.secondarySalesAllowed = true;
        creditManagerBaseInit.signer = creditSigner.addr;
        creditManagerBaseInit.mana = IERC20(addresses.mana);

        CreditManagerHarness creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );

        CreditManagerHarness.Credit[] memory credits = new CreditManagerHarness.Credit[](1);
        credits[0].expiration = type(uint256).max;
        credits[0].amount = 1 ether;
        bytes32 digest =
            keccak256(abi.encode(address(this), address(creditManager), block.chainid, credits[0].amount, credits[0].expiration, credits[0].salt));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditSigner.privateKey, digest);
        credits[0].signature = abi.encodePacked(r, s, v);

        vm.expectRevert("The NFT Address should be a contract");
        creditManager.executeMarketplaceExecuteOrder(address(0), 0, 0, "", credits);
    }

    function test_executeMarketplaceExecuteOrder_RevertsIfTheAssetWasNotPublished() public {
        Vm.Wallet memory creditSigner = vm.createWallet("creditSigner");

        CreditManagerHarness.CollectionStoreStrategyInit memory collectionStoreStrategyInit;
        CreditManagerHarness.MarketplaceStrategyInit memory marketplaceStrategyInit;
        CreditManagerHarness.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit;
        CreditManagerHarness.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit;
        CreditManagerHarness.CreditManagerBaseInit memory creditManagerBaseInit;

        marketplaceStrategyInit.marketplace = IMarketplace(addresses.marketplace);

        creditManagerBaseInit.secondarySalesAllowed = true;
        creditManagerBaseInit.signer = creditSigner.addr;
        creditManagerBaseInit.mana = IERC20(addresses.mana);

        CreditManagerHarness creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );

        CreditManagerHarness.Credit[] memory credits = new CreditManagerHarness.Credit[](1);
        credits[0].expiration = type(uint256).max;
        credits[0].amount = 1 ether;
        bytes32 digest =
            keccak256(abi.encode(address(this), address(creditManager), block.chainid, credits[0].amount, credits[0].expiration, credits[0].salt));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditSigner.privateKey, digest);
        credits[0].signature = abi.encodePacked(r, s, v);

        vm.expectRevert("Asset not published");
        creditManager.executeMarketplaceExecuteOrder(addresses.land, 0, 0, "", credits);
    }

    function test_executeMarketplaceExecuteOrder_RevertsIfThePriceIsNotCorrect() public {
        Vm.Wallet memory creditSigner = vm.createWallet("creditSigner");

        CreditManagerHarness.CollectionStoreStrategyInit memory collectionStoreStrategyInit;
        CreditManagerHarness.MarketplaceStrategyInit memory marketplaceStrategyInit;
        CreditManagerHarness.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit;
        CreditManagerHarness.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit;
        CreditManagerHarness.CreditManagerBaseInit memory creditManagerBaseInit;

        marketplaceStrategyInit.marketplace = IMarketplace(addresses.marketplace);

        creditManagerBaseInit.secondarySalesAllowed = true;
        creditManagerBaseInit.signer = creditSigner.addr;
        creditManagerBaseInit.mana = IERC20(addresses.mana);

        CreditManagerHarness creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );

        CreditManagerHarness.Credit[] memory credits = new CreditManagerHarness.Credit[](1);
        credits[0].expiration = type(uint256).max;
        credits[0].amount = 1 ether;
        bytes32 digest =
            keccak256(abi.encode(address(this), address(creditManager), block.chainid, credits[0].amount, credits[0].expiration, credits[0].salt));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditSigner.privateKey, digest);
        credits[0].signature = abi.encodePacked(r, s, v);

        vm.prank(addresses.landSeller);
        (bool success,) = address(addresses.land).call(
            abi.encodeWithSelector(bytes4(keccak256("setApprovalForAll(address,bool)")), address(marketplaceStrategyInit.marketplace), true)
        );
        require(success, "Failed to set approval for all");

        vm.prank(addresses.landSeller);
        (success,) = address(marketplaceStrategyInit.marketplace).call(
            abi.encodeWithSelector(
                bytes4(keccak256("createOrder(address,uint256,uint256,uint256)")), addresses.land, landTokenId, 1 ether, type(uint256).max
            )
        );
        require(success, "Failed to create order");

        vm.expectRevert("The price is not correct");
        creditManager.executeMarketplaceExecuteOrder(addresses.land, landTokenId, 0, "", credits);
    }

    function test_executeMarketplaceExecuteOrder_RevertsIfNotEnoughManaBalanceInContract() public {
        Vm.Wallet memory creditSigner = vm.createWallet("creditSigner");

        CreditManagerHarness.CollectionStoreStrategyInit memory collectionStoreStrategyInit;
        CreditManagerHarness.MarketplaceStrategyInit memory marketplaceStrategyInit;
        CreditManagerHarness.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit;
        CreditManagerHarness.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit;
        CreditManagerHarness.CreditManagerBaseInit memory creditManagerBaseInit;

        marketplaceStrategyInit.marketplace = IMarketplace(addresses.marketplace);

        creditManagerBaseInit.secondarySalesAllowed = true;
        creditManagerBaseInit.signer = creditSigner.addr;
        creditManagerBaseInit.mana = IERC20(addresses.mana);

        CreditManagerHarness creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );

        CreditManagerHarness.Credit[] memory credits = new CreditManagerHarness.Credit[](1);
        credits[0].expiration = type(uint256).max;
        credits[0].amount = 1 ether;
        bytes32 digest =
            keccak256(abi.encode(address(this), address(creditManager), block.chainid, credits[0].amount, credits[0].expiration, credits[0].salt));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditSigner.privateKey, digest);
        credits[0].signature = abi.encodePacked(r, s, v);

        vm.prank(addresses.landSeller);
        (bool success,) = address(addresses.land).call(
            abi.encodeWithSelector(bytes4(keccak256("setApprovalForAll(address,bool)")), address(marketplaceStrategyInit.marketplace), true)
        );
        require(success, "Failed to set approval for all");

        vm.prank(addresses.landSeller);
        (success,) = address(marketplaceStrategyInit.marketplace).call(
            abi.encodeWithSelector(
                bytes4(keccak256("createOrder(address,uint256,uint256,uint256)")), addresses.land, landTokenId, 1 ether, type(uint256).max
            )
        );
        require(success, "Failed to create order");

        vm.expectRevert();
        creditManager.executeMarketplaceExecuteOrder(addresses.land, landTokenId, 1 ether, "", credits);
    }

    function test_executeMarketplaceExecuteOrder_Success() public {
        Vm.Wallet memory creditSigner = vm.createWallet("creditSigner");

        CreditManagerHarness.CollectionStoreStrategyInit memory collectionStoreStrategyInit;
        CreditManagerHarness.MarketplaceStrategyInit memory marketplaceStrategyInit;
        CreditManagerHarness.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit;
        CreditManagerHarness.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit;
        CreditManagerHarness.CreditManagerBaseInit memory creditManagerBaseInit;

        marketplaceStrategyInit.marketplace = IMarketplace(addresses.marketplace);

        creditManagerBaseInit.secondarySalesAllowed = true;
        creditManagerBaseInit.signer = creditSigner.addr;
        creditManagerBaseInit.mana = IERC20(addresses.mana);

        CreditManagerHarness creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );

        CreditManagerHarness.Credit[] memory credits = new CreditManagerHarness.Credit[](1);
        credits[0].expiration = type(uint256).max;
        credits[0].amount = 1 ether;
        bytes32 digest =
            keccak256(abi.encode(address(this), address(creditManager), block.chainid, credits[0].amount, credits[0].expiration, credits[0].salt));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creditSigner.privateKey, digest);
        credits[0].signature = abi.encodePacked(r, s, v);

        vm.prank(addresses.landSeller);
        (bool success,) = address(addresses.land).call(
            abi.encodeWithSelector(bytes4(keccak256("setApprovalForAll(address,bool)")), address(marketplaceStrategyInit.marketplace), true)
        );
        require(success, "Failed to set approval for all");

        vm.prank(addresses.landSeller);
        (success,) = address(marketplaceStrategyInit.marketplace).call(
            abi.encodeWithSelector(
                bytes4(keccak256("createOrder(address,uint256,uint256,uint256)")), addresses.land, landTokenId, 1 ether, type(uint256).max
            )
        );
        require(success, "Failed to create order");

        vm.prank(addresses.mana);
        (success,) = address(address(creditManagerBaseInit.mana)).call(
            abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), address(creditManager), 1 ether)
        );
        require(success, "Failed to transfer mana");

        uint256 creditManagerBalanceBefore = IERC20(addresses.mana).balanceOf(address(creditManager));
        uint256 buyerBalanceBefore = IERC20(addresses.mana).balanceOf(address(this));
        uint256 landSellerBalanceBefore = IERC20(addresses.mana).balanceOf(addresses.landSeller);
        uint256 spentCreditsBefore = creditManager.spentCredits(keccak256(credits[0].signature));

        vm.expectEmit(address(creditManager));
        emit CreditConsumed(address(this), credits[0]);
        creditManager.executeMarketplaceExecuteOrder(addresses.land, landTokenId, 1 ether, "", credits);

        assertEq(IERC20(addresses.mana).balanceOf(address(creditManager)), creditManagerBalanceBefore - 1 ether);
        assertEq(IERC20(addresses.mana).balanceOf(address(this)), buyerBalanceBefore);
        assertEq(IERC20(addresses.mana).balanceOf(addresses.landSeller), landSellerBalanceBefore + 0.975 ether);
        assertEq(creditManager.spentCredits(keccak256(credits[0].signature)), spentCreditsBefore + 1 ether);
    }
}
