// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {CreditsManagerPolygonWithMANAClaim as CreditsManagerPolygon} from "src/credits/CreditsManagerPolygonWithMANAClaim.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";
import {CreditsManagerPolygonWithMANAClaimHarness} from "test/credits/utils/CreditsManagerPolygonWithMANAClaimHarness.sol";

contract CreditsManagerPolygonWithMANAClaimTestBase is Test, IERC721Receiver {
    address internal owner;
    address internal creditsSigner;
    uint256 internal creditsSignerPk;
    address internal pauser;
    address internal userDenier;
    address internal creditsRevoker;
    address internal customExternalCallSigner;
    uint256 internal customExternalCallSignerPk;
    address internal customExternalCallRevoker;
    address internal metaTxSigner;
    uint256 internal metaTxSignerPk;
    address internal mana;
    uint256 internal maxManaCreditedPerHour;
    bool internal primarySalesAllowed;
    bool internal secondarySalesAllowed;
    bool internal bidsAllowed;
    address internal marketplace;
    address internal legacyMarketplace;
    address internal collectionStore;
    address internal collectionFactory;
    address internal collectionFactoryV3;

    CreditsManagerPolygonWithMANAClaimHarness internal creditsManager;

    address internal manaHolder;

    address internal collection;
    uint256 internal collectionTokenId;
    address internal collectionTokenOwner;
    uint256 internal collectionItemId;
    address internal collectionCreator;

    address internal seller;
    uint256 internal sellerPk;

    event UserDenied(address indexed _sender, address indexed _user, bool _isDenied);
    event CreditRevoked(address indexed _sender, bytes32 indexed _creditId);
    event ERC20Withdrawn(address indexed _sender, address indexed _token, uint256 _amount, address indexed _to);
    event ERC721Withdrawn(address indexed _sender, address indexed _token, uint256 indexed _tokenId, address _to);
    event CustomExternalCallAllowed(address indexed _sender, address indexed _target, bytes4 indexed _selector, bool _allowed);
    event CustomExternalCallRevoked(address indexed _sender, bytes32 indexed _customExternalCallHash);
    event CreditUsed(address indexed _sender, bytes32 indexed _creditId, CreditsManagerPolygon.Credit _credit, uint256 _value);
    event CreditsUsed(address indexed _sender, uint256 _manaTransferred, uint256 _creditedValue);
    event MaxManaCreditedPerHourUpdated(address indexed _sender, uint256 _maxManaCreditedPerHour);
    event PrimarySalesAllowedUpdated(address indexed _sender, bool _primarySalesAllowed);
    event SecondarySalesAllowedUpdated(address indexed _sender, bool _secondarySalesAllowed);

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setUp() public virtual {
        vm.selectFork(vm.createFork("https://rpc.decentraland.org/polygon", 68650527)); // Mar-04-2025 09:10:51 PM +UTC

        owner = makeAddr("owner");
        (creditsSigner, creditsSignerPk) = makeAddrAndKey("creditsSigner");
        pauser = makeAddr("pauser");
        userDenier = makeAddr("userDenier");
        creditsRevoker = makeAddr("creditsRevoker");
        (customExternalCallSigner, customExternalCallSignerPk) = makeAddrAndKey("customExternalCallSigner");
        customExternalCallRevoker = makeAddr("customExternalCallRevoker");
        (metaTxSigner, metaTxSignerPk) = makeAddrAndKey("metaTxSigner");

        CreditsManagerPolygon.Roles memory roles = CreditsManagerPolygon.Roles({
            owner: owner,
            creditsSigner: creditsSigner,
            pauser: pauser,
            userDenier: userDenier,
            creditsRevoker: creditsRevoker,
            customExternalCallSigner: customExternalCallSigner,
            customExternalCallRevoker: customExternalCallRevoker
        });

        mana = 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4;
        maxManaCreditedPerHour = 100 ether;
        primarySalesAllowed = true;
        secondarySalesAllowed = true;
        marketplace = 0x540fb08eDb56AaE562864B390542C97F562825BA;
        legacyMarketplace = 0x480a0f4e360E8964e68858Dd231c2922f1df45Ef;
        collectionStore = 0x214ffC0f0103735728dc66b61A22e4F163e275ae;
        collectionFactory = 0xB549B2442b2BD0a53795BC5cDcBFE0cAF7ACA9f8;
        collectionFactoryV3 = 0x3195e88aE10704b359764CB38e429D24f1c2f781;

        creditsManager = new CreditsManagerPolygonWithMANAClaimHarness(
            roles,
            maxManaCreditedPerHour,
            primarySalesAllowed,
            secondarySalesAllowed,
            IERC20(mana),
            marketplace,
            legacyMarketplace,
            collectionStore,
            ICollectionFactory(collectionFactory),
            ICollectionFactory(collectionFactoryV3)
        );

        manaHolder = 0xB08E3e7cc815213304d884C88cA476ebC50EaAB2;

        collection = 0x96054dc54939D3C632796DbCE4884705ed7C8977;
        collectionTokenId = 1;
        collectionItemId = 0;
        collectionTokenOwner = 0xFE705eaD02E849E78278C50de3d939bE23448F1a;
        collectionCreator = 0xFE705eaD02E849E78278C50de3d939bE23448F1a;

        (seller, sellerPk) = makeAddrAndKey("seller");
    }
}
