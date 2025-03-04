// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {CreditsManagerPolygon} from "src/credits/CreditsManagerPolygon.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";
import {CreditsManagerPolygonHarness} from "test/credits/utils/CreditsManagerPolygonHarness.sol";

contract CreditsManagerPolygonTestBase is Test {
    address internal owner;
    address internal signer;
    uint256 internal signerPk;
    address internal pauser;
    address internal denier;
    address internal revoker;
    address internal customExternalCallSigner;
    uint256 internal customExternalCallSignerPk;
    address internal customExternalCallRevoker;
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

    CreditsManagerPolygonHarness internal creditsManager;

    address internal manaHolder;

    address internal collection;
    uint256 internal collectionTokenId;
    address internal collectionTokenOwner;
    uint256 internal collectionItemId;
    address internal collectionCreator;

    address internal other;

    event UserDenied(address indexed _user);
    event UserAllowed(address indexed _user);
    event CreditRevoked(bytes32 indexed _creditId);
    event MaxManaCreditedPerHourUpdated(uint256 _maxManaCreditedPerHour);
    event PrimarySalesAllowedUpdated(bool _primarySalesAllowed);
    event SecondarySalesAllowedUpdated(bool _secondarySalesAllowed);
    event BidsAllowedUpdated(bool _bidsAllowed);
    event CustomExternalCallAllowed(address indexed _target, bytes4 indexed _selector, bool _allowed);
    event CustomExternalCallRevoked(bytes32 indexed _hashedExternalCallSignature);
    event CreditUsed(bytes32 indexed _creditId, CreditsManagerPolygon.Credit _credit, uint256 _value);
    event CreditsUsed(uint256 _manaTransferred, uint256 _creditedValue);
    event ERC20Withdrawn(address indexed _token, uint256 _amount, address indexed _to);
    event ERC721Withdrawn(address indexed _collection, uint256 _tokenId, address indexed _to);

    function setUp() public {
        vm.selectFork(vm.createFork("https://rpc.decentraland.org/polygon", 68650527)); // Mar-04-2025 09:10:51 PM +UTC

        owner = makeAddr("owner");
        (signer, signerPk) = makeAddrAndKey("signer");
        pauser = makeAddr("pauser");
        denier = makeAddr("denier");
        revoker = makeAddr("revoker");
        (customExternalCallSigner, customExternalCallSignerPk) = makeAddrAndKey("customExternalCallSigner");
        customExternalCallRevoker = makeAddr("customExternalCallRevoker");

        CreditsManagerPolygon.Roles memory roles = CreditsManagerPolygon.Roles({
            owner: owner,
            signer: signer,
            pauser: pauser,
            denier: denier,
            revoker: revoker,
            customExternalCallSigner: customExternalCallSigner,
            customExternalCallRevoker: customExternalCallRevoker
        });

        mana = 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4;
        maxManaCreditedPerHour = 100 ether;
        primarySalesAllowed = true;
        secondarySalesAllowed = true;
        bidsAllowed = true;
        marketplace = 0x540fb08eDb56AaE562864B390542C97F562825BA;
        legacyMarketplace = 0x480a0f4e360E8964e68858Dd231c2922f1df45Ef;
        collectionStore = 0x214ffC0f0103735728dc66b61A22e4F163e275ae;
        collectionFactory = 0xB549B2442b2BD0a53795BC5cDcBFE0cAF7ACA9f8;
        collectionFactoryV3 = 0x3195e88aE10704b359764CB38e429D24f1c2f781;

        creditsManager = new CreditsManagerPolygonHarness(
            roles,
            maxManaCreditedPerHour,
            primarySalesAllowed,
            secondarySalesAllowed,
            bidsAllowed,
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

        other = makeAddr("other");
    }
}
