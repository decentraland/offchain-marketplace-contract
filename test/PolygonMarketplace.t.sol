// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {VmSafe} from "lib/forge-std/src/Vm.sol";
import {PolygonMarketplace} from "../src/PolygonMarketplace.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";

contract MarketplaceHarness is PolygonMarketplace {
    constructor(address _owner) PolygonMarketplace(_owner) {}

    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function hashTrade(Trade memory _trade) external pure returns (bytes32) {
        return _hashTrade(_trade);
    }
}

contract PolygonMarketplaceTest is Test {
    VmSafe.Wallet signer;
    address caller;

    MarketplaceHarness marketplace;

    error UnsupportedAssetType(uint256 _assetType);
    error InvalidFingerprint();

    function setUp() public {
        string memory rpcUrl = "https://rpc.decentraland.org/polygon";
        uint256 blockNumber = 56166590; // Apr-23-2024 03:17:09 PM +UTC

        uint256 forkId = vm.createFork(rpcUrl, blockNumber);
        vm.selectFork(forkId);

        signer = vm.createWallet("signer");
        caller = vm.addr(0xB0C4);

        address owner = vm.addr(0x1);
        marketplace = new MarketplaceHarness(owner);
    }

    function test_accept_RevertsIfUnsupportedAssetType() public {
        uint256 assetType = 3;

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        {
            trades[0].expiration = block.timestamp;

            trades[0].sent = new MarketplaceHarness.Asset[](1);
            trades[0].sent[0].assetType = assetType;

            (uint8 v, bytes32 r, bytes32 s) =
                vm.sign(signer.privateKey, MessageHashUtils.toTypedDataHash(marketplace.getDomainSeparator(), marketplace.hashTrade(trades[0])));

            trades[0].signer = signer.addr;
            trades[0].signature = abi.encodePacked(r, s, v);
        }

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedAssetType.selector, assetType));
        marketplace.accept(trades);
    }

    function test_accept_sendWearable_receiveMANA() public {
        IERC20 mana = IERC20(0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4);
        IERC721 collection = IERC721(0x04e154dB53007bDfF215cc95b944018bBac81bc0);
        uint256 tokenId = 8;

        {
            address originalNftOwner = 0xa6c6DC29B99E8e7c919a5d2Ea426874ad15eA0ed;
            address originalManaHolder = 0x673e6B75a58354919FF5db539AA426727B385D17;

            vm.prank(originalNftOwner);
            collection.transferFrom(originalNftOwner, signer.addr, tokenId);

            vm.prank(originalManaHolder);
            mana.transfer(caller, 1 ether);

            vm.prank(signer.addr);
            collection.setApprovalForAll(address(marketplace), true);

            vm.prank(caller);
            mana.approve(address(marketplace), 1 ether);

            assertEq(collection.ownerOf(tokenId), signer.addr);
            assertEq(mana.balanceOf(caller), 1 ether);
        }

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        {
            trades[0].expiration = block.timestamp;

            trades[0].sent = new MarketplaceHarness.Asset[](1);

            trades[0].sent[0].assetType = marketplace.ERC721_ID();
            trades[0].sent[0].contractAddress = address(collection);
            trades[0].sent[0].value = tokenId;

            trades[0].received = new MarketplaceHarness.Asset[](1);

            trades[0].received[0].assetType = marketplace.ERC20_ID();
            trades[0].received[0].contractAddress = address(mana);
            trades[0].received[0].value = 1 ether;

            (uint8 v, bytes32 r, bytes32 s) =
                vm.sign(signer.privateKey, MessageHashUtils.toTypedDataHash(marketplace.getDomainSeparator(), marketplace.hashTrade(trades[0])));

            trades[0].signer = signer.addr;
            trades[0].signature = abi.encodePacked(r, s, v);
        }

        vm.prank(caller);
        marketplace.accept(trades);

        assertEq(collection.ownerOf(tokenId), caller);
        assertEq(mana.balanceOf(signer.addr), 1 ether);
    }

    function test_accept_sendWearable_receiveMANA_withDAOFee() public {
        IERC20 mana = IERC20(0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4);
        IERC721 collection = IERC721(0x04e154dB53007bDfF215cc95b944018bBac81bc0);
        uint256 tokenId = 8;
        address dao = 0xB08E3e7cc815213304d884C88cA476ebC50EaAB2;
        uint256 daoBalance = mana.balanceOf(dao);

        {
            address originalNftOwner = 0xa6c6DC29B99E8e7c919a5d2Ea426874ad15eA0ed;
            address originalManaHolder = 0x673e6B75a58354919FF5db539AA426727B385D17;

            vm.prank(originalNftOwner);
            collection.transferFrom(originalNftOwner, signer.addr, tokenId);

            vm.prank(originalManaHolder);
            mana.transfer(caller, 1 ether);

            vm.prank(signer.addr);
            collection.setApprovalForAll(address(marketplace), true);

            vm.prank(caller);
            mana.approve(address(marketplace), 1 ether);

            assertEq(collection.ownerOf(tokenId), signer.addr);
            assertEq(mana.balanceOf(caller), 1 ether);
        }

        MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

        {
            trades[0].expiration = block.timestamp;

            trades[0].sent = new MarketplaceHarness.Asset[](1);

            trades[0].sent[0].assetType = marketplace.ERC721_ID();
            trades[0].sent[0].contractAddress = address(collection);
            trades[0].sent[0].value = tokenId;

            trades[0].received = new MarketplaceHarness.Asset[](2);

            trades[0].received[0].assetType = marketplace.ERC20_ID();
            trades[0].received[0].contractAddress = address(mana);
            trades[0].received[0].value = 0.7 ether;

            trades[0].received[1].assetType = marketplace.ERC20_ID();
            trades[0].received[1].contractAddress = address(mana);
            trades[0].received[1].value = 0.3 ether;
            trades[0].received[1].beneficiary = dao;

            (uint8 v, bytes32 r, bytes32 s) =
                vm.sign(signer.privateKey, MessageHashUtils.toTypedDataHash(marketplace.getDomainSeparator(), marketplace.hashTrade(trades[0])));

            trades[0].signer = signer.addr;
            trades[0].signature = abi.encodePacked(r, s, v);
        }

        vm.prank(caller);
        marketplace.accept(trades);

        assertEq(collection.ownerOf(tokenId), caller);
        assertEq(mana.balanceOf(signer.addr), 0.7 ether);
        assertEq(mana.balanceOf(dao), daoBalance + 0.3 ether);
    }

    

    // function test_accept_sendEstate_receiveMANA() public {
    //     IERC20 mana = IERC20(0x0F5D2fB29fb7d3CFeE444a200298f468908cC942);
    //     IComposableERC721 estate = IComposableERC721(0x959e104E1a4dB6317fA58F8295F586e1A978c297);
    //     uint256 estateId = 5668;

    //     {
    //         address originalEstateOwner = 0x877a61D298eAf59f6d574e089216aC764ec00D2D;
    //         address originalManaHolder = 0x46f80018211D5cBBc988e853A8683501FCA4ee9b;

    //         vm.prank(originalEstateOwner);
    //         estate.transferFrom(originalEstateOwner, signer.addr, estateId);

    //         vm.prank(originalManaHolder);
    //         mana.transfer(caller, 1 ether);

    //         vm.prank(signer.addr);
    //         estate.setApprovalForAll(address(marketplace), true);

    //         vm.prank(caller);
    //         mana.approve(address(marketplace), 1 ether);

    //         assertEq(estate.ownerOf(estateId), signer.addr);
    //         assertEq(mana.balanceOf(caller), 1 ether);
    //     }

    //     MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

    //     {
    //         trades[0].expiration = block.timestamp;

    //         trades[0].sent = new MarketplaceHarness.Asset[](1);

    //         trades[0].sent[0].assetType = marketplace.COMPOSABLE_ERC721_ID();
    //         trades[0].sent[0].contractAddress = address(estate);
    //         trades[0].sent[0].value = estateId;
    //         trades[0].sent[0].extra = abi.encode(estate.getFingerprint(estateId), bytes(""));

    //         trades[0].received = new MarketplaceHarness.Asset[](1);

    //         trades[0].received[0].assetType = marketplace.ERC20_ID();
    //         trades[0].received[0].contractAddress = address(mana);
    //         trades[0].received[0].value = 1 ether;

    //         (uint8 v, bytes32 r, bytes32 s) =
    //             vm.sign(signer.privateKey, MessageHashUtils.toTypedDataHash(marketplace.getDomainSeparator(), marketplace.hashTrade(trades[0])));

    //         trades[0].signer = signer.addr;
    //         trades[0].signature = abi.encodePacked(r, s, v);
    //     }

    //     vm.prank(caller);
    //     marketplace.accept(trades);

    //     assertEq(estate.ownerOf(estateId), caller);
    //     assertEq(mana.balanceOf(signer.addr), 1 ether);
    // }

    // function test_accept_sendEstate_receiveMANA_RevertsIfFingerprintIsInvalid() public {
    //     IERC20 mana = IERC20(0x0F5D2fB29fb7d3CFeE444a200298f468908cC942);
    //     IComposableERC721 estate = IComposableERC721(0x959e104E1a4dB6317fA58F8295F586e1A978c297);
    //     uint256 estateId = 5668;

    //     {
    //         address originalEstateOwner = 0x877a61D298eAf59f6d574e089216aC764ec00D2D;
    //         address originalManaHolder = 0x46f80018211D5cBBc988e853A8683501FCA4ee9b;

    //         vm.prank(originalEstateOwner);
    //         estate.transferFrom(originalEstateOwner, signer.addr, estateId);

    //         vm.prank(originalManaHolder);
    //         mana.transfer(caller, 1 ether);

    //         vm.prank(signer.addr);
    //         estate.setApprovalForAll(address(marketplace), true);

    //         vm.prank(caller);
    //         mana.approve(address(marketplace), 1 ether);

    //         assertEq(estate.ownerOf(estateId), signer.addr);
    //         assertEq(mana.balanceOf(caller), 1 ether);
    //     }

    //     MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

    //     {
    //         trades[0].expiration = block.timestamp;

    //         trades[0].sent = new MarketplaceHarness.Asset[](1);

    //         trades[0].sent[0].assetType = marketplace.COMPOSABLE_ERC721_ID();
    //         trades[0].sent[0].contractAddress = address(estate);
    //         trades[0].sent[0].value = estateId;
    //         trades[0].sent[0].extra = abi.encode(bytes32(uint256(123)), bytes(""));

    //         trades[0].received = new MarketplaceHarness.Asset[](1);

    //         trades[0].received[0].assetType = marketplace.ERC20_ID();
    //         trades[0].received[0].contractAddress = address(mana);
    //         trades[0].received[0].value = 1 ether;

    //         (uint8 v, bytes32 r, bytes32 s) =
    //             vm.sign(signer.privateKey, MessageHashUtils.toTypedDataHash(marketplace.getDomainSeparator(), marketplace.hashTrade(trades[0])));

    //         trades[0].signer = signer.addr;
    //         trades[0].signature = abi.encodePacked(r, s, v);
    //     }

    //     vm.prank(caller);
    //     vm.expectRevert(InvalidFingerprint.selector);
    //     marketplace.accept(trades);
    // }

    // function test_accept_sendName_receiveMANA() public {
    //     IERC20 mana = IERC20(0x0F5D2fB29fb7d3CFeE444a200298f468908cC942);
    //     IERC721 registrar = IERC721(0x2A187453064356c898cAe034EAed119E1663ACb8);
    //     uint256 nameId = 111953866685194181316179970749576144183152508562302674483221441304598033207711;

    //     {
    //         address originalNameOwner = 0x6a45De91B516C17CacEC184506d719947613465E;
    //         address originalManaHolder = 0x46f80018211D5cBBc988e853A8683501FCA4ee9b;

    //         vm.prank(originalNameOwner);
    //         registrar.transferFrom(originalNameOwner, signer.addr, nameId);

    //         vm.prank(originalManaHolder);
    //         mana.transfer(caller, 1 ether);

    //         vm.prank(signer.addr);
    //         registrar.setApprovalForAll(address(marketplace), true);

    //         vm.prank(caller);
    //         mana.approve(address(marketplace), 1 ether);

    //         assertEq(registrar.ownerOf(nameId), signer.addr);
    //         assertEq(mana.balanceOf(caller), 1 ether);
    //     }

    //     MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

    //     {
    //         trades[0].expiration = block.timestamp;

    //         trades[0].sent = new MarketplaceHarness.Asset[](1);

    //         trades[0].sent[0].assetType = marketplace.ERC721_ID();
    //         trades[0].sent[0].contractAddress = address(registrar);
    //         trades[0].sent[0].value = nameId;

    //         trades[0].received = new MarketplaceHarness.Asset[](1);

    //         trades[0].received[0].assetType = marketplace.ERC20_ID();
    //         trades[0].received[0].contractAddress = address(mana);
    //         trades[0].received[0].value = 1 ether;

    //         (uint8 v, bytes32 r, bytes32 s) =
    //             vm.sign(signer.privateKey, MessageHashUtils.toTypedDataHash(marketplace.getDomainSeparator(), marketplace.hashTrade(trades[0])));

    //         trades[0].signer = signer.addr;
    //         trades[0].signature = abi.encodePacked(r, s, v);
    //     }

    //     vm.prank(caller);
    //     marketplace.accept(trades);

    //     assertEq(registrar.ownerOf(nameId), caller);
    //     assertEq(mana.balanceOf(signer.addr), 1 ether);
    // }

    // function test_accept_sendNameLANDAndEstate_receiveMANA() public {
    //     IERC20 mana = IERC20(0x0F5D2fB29fb7d3CFeE444a200298f468908cC942);

    //     IERC721 land = IERC721(0xF87E31492Faf9A91B02Ee0dEAAd50d51d56D5d4d);
    //     uint256 landId = 20416942015256307807802476445906092687221;

    //     IComposableERC721 estate = IComposableERC721(0x959e104E1a4dB6317fA58F8295F586e1A978c297);
    //     uint256 estateId = 5668;

    //     IERC721 registrar = IERC721(0x2A187453064356c898cAe034EAed119E1663ACb8);
    //     uint256 nameId = 111953866685194181316179970749576144183152508562302674483221441304598033207711;

    //     {
    //         address originalLandOwner = 0x9cbe520Aa4bFD545109026Bb1fdf9Ea54f476e5E;
    //         address originalEstateOwner = 0x877a61D298eAf59f6d574e089216aC764ec00D2D;
    //         address originalNameOwner = 0x6a45De91B516C17CacEC184506d719947613465E;
    //         address originalManaHolder = 0x46f80018211D5cBBc988e853A8683501FCA4ee9b;

    //         vm.prank(originalLandOwner);
    //         land.transferFrom(originalLandOwner, signer.addr, landId);

    //         vm.prank(originalEstateOwner);
    //         estate.transferFrom(originalEstateOwner, signer.addr, estateId);

    //         vm.prank(originalNameOwner);
    //         registrar.transferFrom(originalNameOwner, signer.addr, nameId);

    //         vm.prank(originalManaHolder);
    //         mana.transfer(caller, 1 ether);

    //         vm.prank(signer.addr);
    //         land.setApprovalForAll(address(marketplace), true);

    //         vm.prank(signer.addr);
    //         estate.setApprovalForAll(address(marketplace), true);

    //         vm.prank(signer.addr);
    //         registrar.setApprovalForAll(address(marketplace), true);

    //         vm.prank(caller);
    //         mana.approve(address(marketplace), 1 ether);

    //         assertEq(land.ownerOf(landId), signer.addr);
    //         assertEq(estate.ownerOf(estateId), signer.addr);
    //         assertEq(registrar.ownerOf(nameId), signer.addr);
    //         assertEq(mana.balanceOf(caller), 1 ether);
    //     }

    //     MarketplaceHarness.Trade[] memory trades = new MarketplaceHarness.Trade[](1);

    //     {
    //         trades[0].expiration = block.timestamp;

    //         trades[0].sent = new MarketplaceHarness.Asset[](3);

    //         trades[0].sent[0].assetType = marketplace.ERC721_ID();
    //         trades[0].sent[0].contractAddress = address(land);
    //         trades[0].sent[0].value = landId;

    //         trades[0].sent[1].assetType = marketplace.COMPOSABLE_ERC721_ID();
    //         trades[0].sent[1].contractAddress = address(estate);
    //         trades[0].sent[1].value = estateId;
    //         trades[0].sent[1].extra = abi.encode(estate.getFingerprint(estateId), bytes(""));

    //         trades[0].sent[2].assetType = marketplace.ERC721_ID();
    //         trades[0].sent[2].contractAddress = address(registrar);
    //         trades[0].sent[2].value = nameId;

    //         trades[0].received = new MarketplaceHarness.Asset[](1);

    //         trades[0].received[0].assetType = marketplace.ERC20_ID();
    //         trades[0].received[0].contractAddress = address(mana);
    //         trades[0].received[0].value = 1 ether;

    //         (uint8 v, bytes32 r, bytes32 s) =
    //             vm.sign(signer.privateKey, MessageHashUtils.toTypedDataHash(marketplace.getDomainSeparator(), marketplace.hashTrade(trades[0])));

    //         trades[0].signer = signer.addr;
    //         trades[0].signature = abi.encodePacked(r, s, v);
    //     }

    //     vm.prank(caller);
    //     marketplace.accept(trades);

    //     assertEq(land.ownerOf(landId), caller);
    //     assertEq(estate.ownerOf(estateId), caller);
    //     assertEq(registrar.ownerOf(nameId), caller);
    //     assertEq(mana.balanceOf(signer.addr), 1 ether);
    // }
}
