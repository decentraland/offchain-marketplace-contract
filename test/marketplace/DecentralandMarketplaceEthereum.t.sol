// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {DecentralandMarketplaceEthereum} from "src/marketplace/DecentralandMarketplaceEthereum.sol";
import {IComposable} from "src/marketplace/interfaces/IComposable.sol";

contract DecentralandMarketplaceEthereumHarness is DecentralandMarketplaceEthereum {
    constructor(
        address _owner,
        address _couponManager,
        address _feeCollector,
        uint256 _feeRate,
        address _manaAddress,
        address _manaEthAggregator,
        uint256 _manaEthAggregatorTolerance,
        address _ethUsdAggregator,
        uint256 _ethUsdAggregatorTolerance
    )
        DecentralandMarketplaceEthereum(
            _owner,
            _couponManager,
            _feeCollector,
            _feeRate,
            _manaAddress,
            _manaEthAggregator,
            _manaEthAggregatorTolerance,
            _ethUsdAggregator,
            _ethUsdAggregatorTolerance
        )
    {}

    function eip712Name() external view returns (string memory) {
        return _EIP712Name();
    }

    function eip712Version() external view returns (string memory) {
        return _EIP712Version();
    }

    function eip712TradeHash(Trade memory _trade) external view returns (bytes32) {
        return _hashTypedDataV4(_hashTrade(_trade));
    }
}

abstract contract DecentralandMarketplaceEthereumTests is Test {
    VmSafe.Wallet signer;
    address other;
    address dao;
    address manaAddress;
    address manaEthAggregator;
    address ethUsdAggregator;
    DecentralandMarketplaceEthereumHarness marketplace;

    error OwnableUnauthorizedAccount(address account);

    function setUp() public virtual {
        uint256 forkId = vm.createFork("https://rpc.decentraland.org/mainnet", 19755898); // Apr-28-2024 07:27:59 PM +UTC
        vm.selectFork(forkId);

        signer = vm.createWallet("signer");
        other = 0x79c63172C7B01A8a5B074EF54428a452E0794E7A;
        dao = 0x9A6ebE7E2a7722F8200d0ffB63a1F6406A0d7dce;
        manaAddress = 0x0F5D2fB29fb7d3CFeE444a200298f468908cC942;
        manaEthAggregator = 0x82A44D92D6c329826dc557c5E1Be6ebeC5D5FeB9;
        ethUsdAggregator = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

        marketplace =
            new DecentralandMarketplaceEthereumHarness(dao, address(0), dao, 25_000, manaAddress, manaEthAggregator, 86400, ethUsdAggregator, 3600);
    }

    function signTrade(DecentralandMarketplaceEthereumHarness.Trade memory _trade) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.privateKey, marketplace.eip712TradeHash(_trade));
        return abi.encodePacked(r, s, v);
    }

    function _getBaseTrades() internal view virtual returns (DecentralandMarketplaceEthereumHarness.Trade[] memory) {
        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = new DecentralandMarketplaceEthereumHarness.Trade[](1);
        trades[0].checks.expiration = block.timestamp;
        trades[0].signer = signer.addr;
        return trades;
    }
}

contract UnsupportedAssetTypeTests is DecentralandMarketplaceEthereumTests {
    error UnsupportedAssetType(uint256 _assetType);

    function test_RevertsIfAssetTypeIsInvalid() public {
        uint256 invalidAssetType = 100;

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTrades();
        trades[0].sent = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].sent[0].assetType = invalidAssetType;
        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedAssetType.selector, invalidAssetType));
        marketplace.accept(trades);
    }
}

contract TransferERC20Tests is DecentralandMarketplaceEthereumTests {
    IERC20 erc20;
    uint256 erc20Sent;
    address erc20OriginalHolder;

    event Transfer(address indexed from, address indexed to, uint256 value);

    error FailedInnerCall();

    function setUp() public override {
        super.setUp();
        erc20 = IERC20(manaAddress);
        erc20Sent = 1 ether;
        erc20OriginalHolder = 0x67c231cF2B0E9518aBa46bDea6b10E0D0C5fEd1B;
    }

    function _getBaseTradesForSent() private view returns (DecentralandMarketplaceEthereumHarness.Trade[] memory) {
        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTrades();
        trades[0].sent = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].sent[0].assetType = marketplace.ASSET_TYPE_ERC20();
        trades[0].sent[0].contractAddress = address(erc20);
        trades[0].sent[0].value = erc20Sent;
        trades[0].signature = signTrade(trades[0]);
        return trades;
    }

    function _getBaseTradesForReceived() private view returns (DecentralandMarketplaceEthereumHarness.Trade[] memory) {
        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTrades();
        trades[0].received = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].received[0].assetType = marketplace.ASSET_TYPE_ERC20();
        trades[0].received[0].contractAddress = address(erc20);
        trades[0].received[0].value = erc20Sent;
        trades[0].signature = signTrade(trades[0]);
        return trades;
    }

    function test_RevertsIfSignerHasNotApprovedTheMarketplaceToSendERC20() public {
        vm.prank(erc20OriginalHolder);
        erc20.transfer(signer.addr, erc20Sent);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForSent();

        vm.prank(other);
        vm.expectRevert(FailedInnerCall.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfCallerHasNotApprovedTheMarketplaceToSendERC20() public {
        vm.prank(erc20OriginalHolder);
        erc20.transfer(other, erc20Sent);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForReceived();

        vm.prank(other);
        vm.expectRevert(FailedInnerCall.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfSignerDoesNotHaveEnoughERC20Balance() public {
        vm.prank(signer.addr);
        erc20.approve(address(marketplace), erc20Sent);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForSent();

        vm.prank(other);
        vm.expectRevert(FailedInnerCall.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfCallerDoesNotHaveEnoughERC20Balance() public {
        vm.prank(other);
        erc20.approve(address(marketplace), erc20Sent);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForReceived();

        vm.prank(other);
        vm.expectRevert(FailedInnerCall.selector);
        marketplace.accept(trades);
    }

    function test_TransfersERC20FromSignerToCaller() public {
        vm.prank(signer.addr);
        erc20.approve(address(marketplace), erc20Sent);

        vm.prank(erc20OriginalHolder);
        erc20.transfer(signer.addr, erc20Sent);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForSent();

        uint256 expectedFee = 0.025 ether;
        uint256 daoBalance = erc20.balanceOf(dao);

        vm.prank(other);
        vm.expectEmit(address(erc20));
        emit Transfer(signer.addr, other, erc20Sent - expectedFee);
        vm.expectEmit(address(erc20));
        emit Transfer(signer.addr, dao, expectedFee);
        marketplace.accept(trades);

        assertEq(erc20.balanceOf(signer.addr), 0);
        assertEq(erc20.balanceOf(other), erc20Sent - expectedFee);
        assertEq(erc20.balanceOf(dao), daoBalance + expectedFee);
    }

    function test_TransfersERC20FromCallerToSigner() public {
        vm.prank(other);
        erc20.approve(address(marketplace), erc20Sent);

        vm.prank(erc20OriginalHolder);
        erc20.transfer(other, erc20Sent);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForReceived();

        uint256 expectedFee = 0.025 ether;
        uint256 daoBalance = erc20.balanceOf(dao);

        vm.prank(other);
        vm.expectEmit(address(erc20));
        emit Transfer(other, signer.addr, erc20Sent - expectedFee);
        vm.expectEmit(address(erc20));
        emit Transfer(other, dao, expectedFee);
        marketplace.accept(trades);

        assertEq(erc20.balanceOf(other), 0);
        assertEq(erc20.balanceOf(signer.addr), erc20Sent - expectedFee);
        assertEq(erc20.balanceOf(dao), daoBalance + expectedFee);
    }
}

contract TransferUsdPeggedManaTests is DecentralandMarketplaceEthereumTests {
    IERC20 erc20;
    address erc20OriginalHolder;

    event Transfer(address indexed from, address indexed to, uint256 value);

    error AggregatorAnswerIsStale();

    function setUp() public override {
        super.setUp();

        erc20 = IERC20(manaAddress);
        erc20OriginalHolder = 0x67c231cF2B0E9518aBa46bDea6b10E0D0C5fEd1B;
    }

    function test_TransfersTheCorrectAmountOfMana() public {
        vm.prank(erc20OriginalHolder);
        erc20.transfer(other, 1000 ether);

        vm.prank(other);
        erc20.approve(address(marketplace), 1000 ether);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = new DecentralandMarketplaceEthereumHarness.Trade[](1);
        trades[0].checks.expiration = block.timestamp;
        trades[0].signer = signer.addr;
        trades[0].received = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].received[0].assetType = marketplace.ASSET_TYPE_USD_PEGGED_MANA();
        trades[0].received[0].value = 100 ether;
        trades[0].signature = signTrade(trades[0]);

        // The amount of MANA to be transferred is 45825737193731408700
        // Which is the equivalent to 45,8257371937314087 MANA
        // That is because the price of MANA is 0.45 USD at the moment of the Trade
        // As the value defined is 100 USD, the amount of MANA to be transferred is 100 * 0.45 = ~45

        vm.expectEmit(address(erc20));
        emit Transfer(other, signer.addr, 44680093763888123483);

        vm.expectEmit(address(erc20));
        emit Transfer(other, dao, 1145643429843285217);

        vm.prank(other);
        marketplace.accept(trades);
    }

    function test_TransfersTheCorrectAmountOfMana_WithRandomAssetContractAddress() public {
        vm.prank(erc20OriginalHolder);
        erc20.transfer(other, 1000 ether);

        vm.prank(other);
        erc20.approve(address(marketplace), 1000 ether);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = new DecentralandMarketplaceEthereumHarness.Trade[](1);
        trades[0].checks.expiration = block.timestamp;
        trades[0].signer = signer.addr;
        trades[0].received = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].received[0].assetType = marketplace.ASSET_TYPE_USD_PEGGED_MANA();
        // The contract address is ignored as it is replaced by the mana contract address
        trades[0].received[0].contractAddress = other;
        trades[0].received[0].value = 100 ether;
        trades[0].signature = signTrade(trades[0]);

        vm.expectEmit(address(erc20));
        emit Transfer(other, signer.addr, 44680093763888123483);

        vm.expectEmit(address(erc20));
        emit Transfer(other, dao, 1145643429843285217);

        vm.prank(other);
        marketplace.accept(trades);
    }

    function test_RevertsIfManaEthAggregatorIsAddressZero() public {
        vm.startPrank(dao);
        marketplace.updateManaEthAggregator(address(0), marketplace.manaEthAggregatorTolerance());
        vm.stopPrank();

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = new DecentralandMarketplaceEthereumHarness.Trade[](1);
        trades[0].checks.expiration = block.timestamp;
        trades[0].signer = signer.addr;
        trades[0].received = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].received[0].assetType = marketplace.ASSET_TYPE_USD_PEGGED_MANA();
        trades[0].received[0].value = 100 ether;
        trades[0].signature = signTrade(trades[0]);

        vm.expectRevert();

        vm.prank(other);
        marketplace.accept(trades);
    }

    function test_RevertsIfManaEthAggregatorToleranceIsZero() public {
        vm.startPrank(dao);
        marketplace.updateManaEthAggregator(address(marketplace.manaEthAggregator()), 0);
        vm.stopPrank();

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = new DecentralandMarketplaceEthereumHarness.Trade[](1);
        trades[0].checks.expiration = block.timestamp;
        trades[0].signer = signer.addr;
        trades[0].received = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].received[0].assetType = marketplace.ASSET_TYPE_USD_PEGGED_MANA();
        trades[0].received[0].value = 100 ether;
        trades[0].signature = signTrade(trades[0]);

        vm.expectRevert(AggregatorAnswerIsStale.selector);

        vm.prank(other);
        marketplace.accept(trades);
    }

    function test_RevertsIfEthUsdAggregatorIsAddressZero() public {
        vm.startPrank(dao);
        marketplace.updateEthUsdAggregator(address(0), marketplace.ethUsdAggregatorTolerance());
        vm.stopPrank();

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = new DecentralandMarketplaceEthereumHarness.Trade[](1);
        trades[0].checks.expiration = block.timestamp;
        trades[0].signer = signer.addr;
        trades[0].received = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].received[0].assetType = marketplace.ASSET_TYPE_USD_PEGGED_MANA();
        trades[0].received[0].value = 100 ether;
        trades[0].signature = signTrade(trades[0]);

        vm.expectRevert();

        vm.prank(other);
        marketplace.accept(trades);
    }

    function test_RevertsIfEthUsdAggregatorToleranceIsZero() public {
        vm.startPrank(dao);
        marketplace.updateEthUsdAggregator(address(marketplace.ethUsdAggregator()), 0);
        vm.stopPrank();

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = new DecentralandMarketplaceEthereumHarness.Trade[](1);
        trades[0].checks.expiration = block.timestamp;
        trades[0].signer = signer.addr;
        trades[0].received = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].received[0].assetType = marketplace.ASSET_TYPE_USD_PEGGED_MANA();
        trades[0].received[0].value = 100 ether;
        trades[0].signature = signTrade(trades[0]);

        vm.expectRevert(AggregatorAnswerIsStale.selector);

        vm.prank(other);
        marketplace.accept(trades);
    }
}

contract TransferERC721Tests is DecentralandMarketplaceEthereumTests {
    IERC721 erc721;
    uint256 erc721TokenId;
    address erc721OriginalHolder;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function setUp() public override {
        super.setUp();
        erc721 = IERC721(0xF87E31492Faf9A91B02Ee0dEAAd50d51d56D5d4d);
        erc721TokenId = 1;
        erc721OriginalHolder = 0x959e104E1a4dB6317fA58F8295F586e1A978c297;
    }

    function _getBaseTradesForSent() private view returns (DecentralandMarketplaceEthereumHarness.Trade[] memory) {
        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTrades();
        trades[0].sent = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].sent[0].assetType = marketplace.ASSET_TYPE_ERC721();
        trades[0].sent[0].contractAddress = address(erc721);
        trades[0].sent[0].value = erc721TokenId;
        trades[0].signature = signTrade(trades[0]);
        return trades;
    }

    function _getBaseTradesForReceived() private view returns (DecentralandMarketplaceEthereumHarness.Trade[] memory) {
        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTrades();
        trades[0].received = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].received[0].assetType = marketplace.ASSET_TYPE_ERC721();
        trades[0].received[0].contractAddress = address(erc721);
        trades[0].received[0].value = erc721TokenId;
        trades[0].signature = signTrade(trades[0]);
        return trades;
    }

    function test_RevertsIfSignerHasNotApprovedTheMarketplaceToSendERC721() public {
        vm.prank(erc721OriginalHolder);
        erc721.transferFrom(erc721OriginalHolder, signer.addr, erc721TokenId);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForSent();

        vm.prank(other);
        vm.expectRevert();
        marketplace.accept(trades);
    }

    function test_RevertsIfCallerHasNotApprovedTheMarketplaceToSendERC721() public {
        vm.prank(erc721OriginalHolder);
        erc721.transferFrom(erc721OriginalHolder, other, erc721TokenId);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForReceived();

        vm.prank(other);
        vm.expectRevert();
        marketplace.accept(trades);
    }

    function test_RevertsIfSignerDoesNotHaveTheERC721Token() public {
        vm.prank(signer.addr);
        erc721.setApprovalForAll(address(marketplace), true);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForSent();

        vm.prank(other);
        vm.expectRevert();
        marketplace.accept(trades);
    }

    function test_RevertsIfCallerDoesNotHaveTheERC721Token() public {
        vm.prank(other);
        erc721.setApprovalForAll(address(marketplace), true);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForReceived();

        vm.prank(other);
        vm.expectRevert();
        marketplace.accept(trades);
    }

    function test_TransfersERC721FromSignerToCaller() public {
        vm.prank(signer.addr);
        erc721.setApprovalForAll(address(marketplace), true);

        vm.prank(erc721OriginalHolder);
        erc721.transferFrom(erc721OriginalHolder, signer.addr, erc721TokenId);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForSent();

        vm.prank(other);
        vm.expectEmit(address(erc721));
        emit Transfer(signer.addr, other, erc721TokenId);
        marketplace.accept(trades);

        assertEq(erc721.ownerOf(erc721TokenId), other);
    }

    function test_TransfersERC721FromCallerToSigner() public {
        vm.prank(other);
        erc721.setApprovalForAll(address(marketplace), true);

        vm.prank(erc721OriginalHolder);
        erc721.transferFrom(erc721OriginalHolder, other, erc721TokenId);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForReceived();

        vm.prank(other);
        vm.expectEmit(address(erc721));
        emit Transfer(other, signer.addr, erc721TokenId);
        marketplace.accept(trades);

        assertEq(erc721.ownerOf(erc721TokenId), signer.addr);
    }
}

contract TransferComposableTokenTests is DecentralandMarketplaceEthereumTests {
    IComposable composable;
    uint256 composableTokenId;
    address composableOriginalHolder;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    error InvalidFingerprint();

    function setUp() public override {
        super.setUp();
        composable = IComposable(0x959e104E1a4dB6317fA58F8295F586e1A978c297);
        composableTokenId = 1;
        composableOriginalHolder = 0x9aBdCb8825696CC2Ef3A0a955f99850418847F5D;
    }

    function _getBaseTradesForSent() private view returns (DecentralandMarketplaceEthereumHarness.Trade[] memory) {
        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTrades();
        trades[0].sent = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].sent[0].assetType = marketplace.ASSET_TYPE_ERC721();
        trades[0].sent[0].contractAddress = address(composable);
        trades[0].sent[0].value = composableTokenId;
        trades[0].sent[0].extra = abi.encode(composable.getFingerprint(composableTokenId));
        trades[0].signature = signTrade(trades[0]);
        return trades;
    }

    function _getBaseTradesForReceived() private view returns (DecentralandMarketplaceEthereumHarness.Trade[] memory) {
        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTrades();
        trades[0].received = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].received[0].assetType = marketplace.ASSET_TYPE_ERC721();
        trades[0].received[0].contractAddress = address(composable);
        trades[0].received[0].value = composableTokenId;
        trades[0].received[0].extra = abi.encode(composable.getFingerprint(composableTokenId));
        trades[0].signature = signTrade(trades[0]);
        return trades;
    }

    function test_RevertsIfSentAssetFingerprintIsInvalid() public {
        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForSent();
        trades[0].sent[0].extra = abi.encode(uint256(123));
        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        vm.expectRevert(InvalidFingerprint.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfReceivedAssetFingerprintIsInvalid() public {
        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForReceived();
        trades[0].received[0].extra = abi.encode(uint256(123));
        trades[0].signature = signTrade(trades[0]);

        vm.prank(other);
        vm.expectRevert(InvalidFingerprint.selector);
        marketplace.accept(trades);
    }

    function test_RevertsIfSignerIsNotTheOwnerOfTheComposableToken() public {
        vm.prank(signer.addr);
        composable.setApprovalForAll(address(marketplace), true);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForSent();

        vm.prank(other);
        vm.expectRevert("Only owner or operator can transfer");
        marketplace.accept(trades);
    }

    function test_RevertsIfCallerIsNotTheOwnerOfTheComposableToken() public {
        vm.prank(other);
        composable.setApprovalForAll(address(marketplace), true);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForReceived();

        vm.prank(other);
        vm.expectRevert("Only owner or operator can transfer");
        marketplace.accept(trades);
    }

    function test_RevertsIfSignerHasNotApprovedTheMarketplaceContractToTransferTheComposableToken() public {
        vm.prank(composableOriginalHolder);
        composable.transferFrom(composableOriginalHolder, signer.addr, composableTokenId);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForSent();

        vm.prank(other);
        vm.expectRevert("Only owner or operator can transfer");
        marketplace.accept(trades);
    }

    function test_RevertsIfCallerHasNotApprovedTheMarketplaceContractToTransferTheComposableToken() public {
        vm.prank(composableOriginalHolder);
        composable.transferFrom(composableOriginalHolder, other, composableTokenId);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForReceived();

        vm.prank(other);
        vm.expectRevert("Only owner or operator can transfer");
        marketplace.accept(trades);
    }

    function test_TransfersComposableTokenFromSignerToCaller() public {
        vm.prank(composableOriginalHolder);
        composable.transferFrom(composableOriginalHolder, signer.addr, composableTokenId);

        vm.prank(signer.addr);
        composable.setApprovalForAll(address(marketplace), true);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForSent();

        vm.prank(other);
        vm.expectEmit(address(composable));
        emit Transfer(signer.addr, other, composableTokenId);
        marketplace.accept(trades);

        assertEq(composable.ownerOf(composableTokenId), other);
    }

    function test_TransfersComposableTokenFromCallerToSigner() public {
        vm.prank(composableOriginalHolder);
        composable.transferFrom(composableOriginalHolder, other, composableTokenId);

        vm.prank(other);
        composable.setApprovalForAll(address(marketplace), true);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = _getBaseTradesForReceived();

        vm.prank(other);
        vm.expectEmit(address(composable));
        emit Transfer(other, signer.addr, composableTokenId);
        marketplace.accept(trades);

        assertEq(composable.ownerOf(composableTokenId), signer.addr);
    }
}

contract UpdateFeeCollectorTests is DecentralandMarketplaceEthereumTests {
    event FeeCollectorUpdated(address indexed _caller, address indexed _feeCollector);

    function test_RevertsIfCallerIsNotTheOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, other));
        marketplace.updateFeeCollector(dao);
    }

    function test_UpdatesFeeCollector() public {
        vm.prank(dao);
        vm.expectEmit(address(marketplace));
        emit FeeCollectorUpdated(dao, other);
        marketplace.updateFeeCollector(other);
        assertEq(marketplace.feeCollector(), other);
    }
}

contract UpdateFeeRateTests is DecentralandMarketplaceEthereumTests {
    event FeeRateUpdated(address indexed _caller, uint256 _feeRate);

    function test_RevertsIfCallerIsNotTheOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, other));
        marketplace.updateFeeRate(100);
    }

    function test_UpdatesFeeRate() public {
        vm.prank(dao);
        vm.expectEmit(address(marketplace));
        emit FeeRateUpdated(dao, 100);
        marketplace.updateFeeRate(100);
        assertEq(marketplace.feeRate(), 100);
    }
}

contract UpdateManaEthAggregatorTests is DecentralandMarketplaceEthereumTests {
    event ManaEthAggregatorUpdated(address indexed _aggregator, uint256 _tolerance);

    function test_RevertsIfCallerIsNotTheOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, other));
        marketplace.updateManaEthAggregator(address(0), 0 seconds);
    }

    function test_UpdatesManaEthAggregator() public {
        assertEq(address(marketplace.manaEthAggregator()), manaEthAggregator);
        assertEq(marketplace.manaEthAggregatorTolerance(), 86400);

        vm.expectEmit(address(marketplace));
        emit ManaEthAggregatorUpdated(other, 100);

        vm.prank(dao);
        marketplace.updateManaEthAggregator(other, 100);

        assertEq(address(marketplace.manaEthAggregator()), other);
        assertEq(marketplace.manaEthAggregatorTolerance(), 100);
    }
}

contract UpdateEthUsdAggregatorTests is DecentralandMarketplaceEthereumTests {
    event EthUsdAggregatorUpdated(address indexed _aggregator, uint256 _tolerance);

    function test_RevertsIfCallerIsNotTheOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, other));
        marketplace.updateEthUsdAggregator(address(0), 0 seconds);
    }

    function test_UpdatesEthUsdAggregator() public {
        assertEq(address(marketplace.ethUsdAggregator()), ethUsdAggregator);
        assertEq(marketplace.ethUsdAggregatorTolerance(), 3600);

        vm.expectEmit(address(marketplace));
        emit EthUsdAggregatorUpdated(other, 100);

        vm.prank(dao);
        marketplace.updateEthUsdAggregator(other, 100);

        assertEq(address(marketplace.ethUsdAggregator()), other);
        assertEq(marketplace.ethUsdAggregatorTolerance(), 100);
    }
}

contract ExampleTests is DecentralandMarketplaceEthereumTests {
    IERC20 mana;
    IERC721 land;
    IERC721 names;
    IComposable estate;

    error ExternalChecksFailed();

    function setUp() public override {
        super.setUp();

        mana = IERC20(manaAddress);
        land = IERC721(0xF87E31492Faf9A91B02Ee0dEAAd50d51d56D5d4d);
        names = IERC721(0x2A187453064356c898cAe034EAed119E1663ACb8);
        estate = IComposable(0x959e104E1a4dB6317fA58F8295F586e1A978c297);

        vm.prank(other);
        mana.approve(address(marketplace), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

        vm.startPrank(signer.addr);
        land.setApprovalForAll(address(marketplace), true);
        names.setApprovalForAll(address(marketplace), true);
        estate.setApprovalForAll(address(marketplace), true);
        vm.stopPrank();

        vm.startPrank(other);
        land.setApprovalForAll(address(marketplace), true);
        names.setApprovalForAll(address(marketplace), true);
        estate.setApprovalForAll(address(marketplace), true);
        vm.stopPrank();
    }

    function test_Trade1LandFor1000ManaWithDAOFee() public {
        address landOriginalOwner = 0x001B71FAD769B3cd47fD4C9849c704FdFaBF6096;
        uint256 landTokenId = 42535295865117307932921825928971026431990;
        vm.prank(landOriginalOwner);
        land.transferFrom(landOriginalOwner, signer.addr, landTokenId);

        address manaOriginalHolder = 0x67c231cF2B0E9518aBa46bDea6b10E0D0C5fEd1B;
        uint256 manaOriginalHolderBalance = mana.balanceOf(manaOriginalHolder);
        vm.prank(manaOriginalHolder);
        mana.transfer(other, manaOriginalHolderBalance);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = new DecentralandMarketplaceEthereumHarness.Trade[](1);
        trades[0].checks.expiration = block.timestamp;
        trades[0].sent = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].sent[0].assetType = marketplace.ASSET_TYPE_ERC721();
        trades[0].sent[0].contractAddress = address(land);
        trades[0].sent[0].value = landTokenId;
        trades[0].received = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].received[0].assetType = marketplace.ASSET_TYPE_ERC20();
        trades[0].received[0].contractAddress = address(mana);
        trades[0].received[0].value = 1000 ether;
        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        assertEq(land.ownerOf(landTokenId), signer.addr);

        uint256 signerBalancePreTrade = mana.balanceOf(signer.addr);
        uint256 callerBalancePreTrade = mana.balanceOf(other);
        uint256 daoBalancePreTrade = mana.balanceOf(dao);

        vm.prank(other);
        marketplace.accept(trades);

        assertEq(land.ownerOf(landTokenId), other);

        assertEq(mana.balanceOf(signer.addr), signerBalancePreTrade + 975 ether);
        assertEq(mana.balanceOf(other), callerBalancePreTrade - 1000 ether);
        assertEq(mana.balanceOf(dao), daoBalancePreTrade + 25 ether);
    }

    function test_Trade1LandFor1000ManaWithDAOFee_CallerHasToOwnDecentralandName() public {
        address landOriginalOwner = 0x001B71FAD769B3cd47fD4C9849c704FdFaBF6096;
        uint256 landTokenId = 42535295865117307932921825928971026431990;
        vm.prank(landOriginalOwner);
        land.transferFrom(landOriginalOwner, signer.addr, landTokenId);

        address manaOriginalHolder = 0x67c231cF2B0E9518aBa46bDea6b10E0D0C5fEd1B;
        uint256 manaOriginalHolderBalance = mana.balanceOf(manaOriginalHolder);
        vm.prank(manaOriginalHolder);
        mana.transfer(other, manaOriginalHolderBalance);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = new DecentralandMarketplaceEthereumHarness.Trade[](1);
        trades[0].checks.expiration = block.timestamp;
        trades[0].checks.externalChecks = new DecentralandMarketplaceEthereumHarness.ExternalCheck[](1);
        trades[0].checks.externalChecks[0].contractAddress = address(names);
        trades[0].checks.externalChecks[0].value = 1;
        trades[0].checks.externalChecks[0].selector = names.balanceOf.selector;
        trades[0].checks.externalChecks[0].required = true;
        trades[0].sent = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].sent[0].assetType = marketplace.ASSET_TYPE_ERC721();
        trades[0].sent[0].contractAddress = address(land);
        trades[0].sent[0].value = landTokenId;
        trades[0].received = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].received[0].assetType = marketplace.ASSET_TYPE_ERC20();
        trades[0].received[0].contractAddress = address(mana);
        trades[0].received[0].value = 1000 ether;
        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        assertEq(land.ownerOf(landTokenId), signer.addr);

        uint256 signerBalancePreTrade = mana.balanceOf(signer.addr);
        uint256 callerBalancePreTrade = mana.balanceOf(other);
        uint256 daoBalancePreTrade = mana.balanceOf(dao);

        vm.prank(other);
        vm.expectRevert(ExternalChecksFailed.selector);
        marketplace.accept(trades);

        address nameOriginalOwner = 0xf0ABCFEAA30A95D32569Fcf2B3a48bc7CB639871;
        vm.prank(nameOriginalOwner);
        names.transferFrom(nameOriginalOwner, other, 100000524771658066136810291574007504540382436851477100100347508325030054457380);

        vm.prank(other);
        marketplace.accept(trades);

        assertEq(land.ownerOf(landTokenId), other);

        assertEq(mana.balanceOf(signer.addr), signerBalancePreTrade + 975 ether);
        assertEq(mana.balanceOf(other), callerBalancePreTrade - 1000 ether);
        assertEq(mana.balanceOf(dao), daoBalancePreTrade + 25 ether);
    }

    function test_Trade3LandFor1000ManaWithDAOFee() public {
        address landOriginalOwner1 = 0x001B71FAD769B3cd47fD4C9849c704FdFaBF6096;
        uint256 landTokenId1 = 42535295865117307932921825928971026431990;
        vm.prank(landOriginalOwner1);
        land.transferFrom(landOriginalOwner1, signer.addr, landTokenId1);

        address landOriginalOwner2 = 0x001e40d30267759828A9022ed8116F7b08E22AD1;
        uint256 landTokenId2 = 40833884030512615615604952891812185374713;
        vm.prank(landOriginalOwner2);
        land.transferFrom(landOriginalOwner2, signer.addr, landTokenId2);

        address landOriginalOwner3 = 0x0020014100F57d2F8785368C8FBc48A302607e20;
        uint256 landTokenId3 = 15312706511442230855851857334429569515624;
        vm.prank(landOriginalOwner3);
        land.transferFrom(landOriginalOwner3, signer.addr, landTokenId3);

        address manaOriginalHolder = 0x67c231cF2B0E9518aBa46bDea6b10E0D0C5fEd1B;
        uint256 manaOriginalHolderBalance = mana.balanceOf(manaOriginalHolder);
        vm.prank(manaOriginalHolder);
        mana.transfer(other, manaOriginalHolderBalance);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = new DecentralandMarketplaceEthereumHarness.Trade[](1);
        trades[0].checks.expiration = block.timestamp;
        trades[0].sent = new DecentralandMarketplaceEthereumHarness.Asset[](3);
        trades[0].sent[0].assetType = marketplace.ASSET_TYPE_ERC721();
        trades[0].sent[0].contractAddress = address(land);
        trades[0].sent[0].value = landTokenId1;
        trades[0].sent[1].assetType = marketplace.ASSET_TYPE_ERC721();
        trades[0].sent[1].contractAddress = address(land);
        trades[0].sent[1].value = landTokenId2;
        trades[0].sent[2].assetType = marketplace.ASSET_TYPE_ERC721();
        trades[0].sent[2].contractAddress = address(land);
        trades[0].sent[2].value = landTokenId3;
        trades[0].received = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].received[0].assetType = marketplace.ASSET_TYPE_ERC20();
        trades[0].received[0].contractAddress = address(mana);
        trades[0].received[0].value = 1000 ether;
        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        assertEq(land.ownerOf(landTokenId1), signer.addr);
        assertEq(land.ownerOf(landTokenId2), signer.addr);
        assertEq(land.ownerOf(landTokenId3), signer.addr);

        uint256 signerBalancePreTrade = mana.balanceOf(signer.addr);
        uint256 callerBalancePreTrade = mana.balanceOf(other);
        uint256 daoBalancePreTrade = mana.balanceOf(dao);

        vm.prank(other);
        marketplace.accept(trades);

        assertEq(land.ownerOf(landTokenId1), other);
        assertEq(land.ownerOf(landTokenId2), other);
        assertEq(land.ownerOf(landTokenId3), other);

        assertEq(mana.balanceOf(signer.addr), signerBalancePreTrade + 975 ether);
        assertEq(mana.balanceOf(other), callerBalancePreTrade - 1000 ether);
        assertEq(mana.balanceOf(dao), daoBalancePreTrade + 25 ether);
    }

    function test_Trade1EstateFor1LandAnd1Name() public {
        address landOriginalOwner = 0x001B71FAD769B3cd47fD4C9849c704FdFaBF6096;
        uint256 landTokenId = 42535295865117307932921825928971026431990;
        vm.prank(landOriginalOwner);
        land.transferFrom(landOriginalOwner, other, landTokenId);

        address nameOriginalOwner = 0xf0ABCFEAA30A95D32569Fcf2B3a48bc7CB639871;
        uint256 nameTokenId = 100000524771658066136810291574007504540382436851477100100347508325030054457380;
        vm.prank(nameOriginalOwner);
        names.transferFrom(nameOriginalOwner, other, nameTokenId);

        address estateOriginalOwner = 0x9aBdCb8825696CC2Ef3A0a955f99850418847F5D;
        uint256 estateTokenId = 1;
        vm.prank(estateOriginalOwner);
        estate.transferFrom(estateOriginalOwner, signer.addr, estateTokenId);

        DecentralandMarketplaceEthereumHarness.Trade[] memory trades = new DecentralandMarketplaceEthereumHarness.Trade[](1);
        trades[0].checks.expiration = block.timestamp;
        trades[0].sent = new DecentralandMarketplaceEthereumHarness.Asset[](1);
        trades[0].sent[0].assetType = marketplace.ASSET_TYPE_ERC721();
        trades[0].sent[0].contractAddress = address(estate);
        trades[0].sent[0].value = estateTokenId;
        trades[0].sent[0].extra = abi.encode(estate.getFingerprint(estateTokenId));
        trades[0].received = new DecentralandMarketplaceEthereumHarness.Asset[](2);
        trades[0].received[0].assetType = marketplace.ASSET_TYPE_ERC721();
        trades[0].received[0].contractAddress = address(land);
        trades[0].received[0].value = landTokenId;
        trades[0].received[1].assetType = marketplace.ASSET_TYPE_ERC721();
        trades[0].received[1].contractAddress = address(names);
        trades[0].received[1].value = nameTokenId;
        trades[0].signer = signer.addr;
        trades[0].signature = signTrade(trades[0]);

        assertEq(estate.ownerOf(estateTokenId), signer.addr);
        assertEq(land.ownerOf(landTokenId), other);
        assertEq(names.ownerOf(nameTokenId), other);

        vm.prank(other);
        marketplace.accept(trades);

        assertEq(estate.ownerOf(estateTokenId), other);
        assertEq(land.ownerOf(landTokenId), signer.addr);
        assertEq(names.ownerOf(nameTokenId), signer.addr);
    }
}
