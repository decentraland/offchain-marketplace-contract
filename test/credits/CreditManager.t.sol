// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// import {Test, console} from "forge-std/Test.sol";
// import {VmSafe} from "forge-std/Vm.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {CreditManager} from "src/credits/CreditManager.sol";
// import {DecentralandMarketplacePolygon} from "src/marketplace/DecentralandMarketplacePolygon.sol";
// import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";

// contract CreditManagerHarness is CreditManager {
//     constructor(
//         address _owner,
//         address _signer,
//         address _pauser,
//         address _denier,
//         DecentralandMarketplacePolygon _marketplace,
//         IERC20 _mana,
//         ICollectionFactory[] memory _factories,
//         bool _primarySalesAllowed,
//         bool _secondarySalesAllowed,
//         uint256 _maxManaTransferPerHour
//     )
//         CreditManager(
//             _owner,
//             _signer,
//             _pauser,
//             _denier,
//             _marketplace,
//             _mana,
//             _factories,
//             _primarySalesAllowed,
//             _secondarySalesAllowed,
//             _maxManaTransferPerHour
//         )
//     {}
// }

// contract CreditManagerTest is Test {
//     // Test Fork
//     uint256 private forkId;

//     // CreditManager Arguments
//     address private owner;
//     VmSafe.Wallet private signer;
//     address private pauser;
//     address private denier;
//     DecentralandMarketplacePolygon private marketplace;
//     IERC20 private mana;
//     ICollectionFactory[] private factories;
//     bool primarySalesAllowed;
//     bool secondarySalesAllowed;
//     uint256 private maxManaTransferPerHour;

//     // CreditManager Instance
//     CreditManagerHarness private creditManager;

//     function setUp() public {
//         forkId = vm.createFork("https://rpc.decentraland.org/polygon", 67186585); // Jan-27-2025 12:05:04 AM +UTC
//         vm.selectFork(forkId);

//         owner = 0x0E659A116e161d8e502F9036bAbDA51334F2667E;
//         signer = vm.createWallet("signer");
//         pauser = makeAddr("pauser");
//         denier = makeAddr("denier");
//         marketplace = DecentralandMarketplacePolygon(0x540fb08eDb56AaE562864B390542C97F562825BA);
//         mana = IERC20(0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4);
//         factories = new ICollectionFactory[](2);
//         factories[0] = ICollectionFactory(0xB549B2442b2BD0a53795BC5cDcBFE0cAF7ACA9f8);
//         factories[1] = ICollectionFactory(0x3195e88aE10704b359764CB38e429D24f1c2f781);
//         primarySalesAllowed = true;
//         secondarySalesAllowed = true;
//         maxManaTransferPerHour = 1000 ether;

//         creditManager = new CreditManagerHarness(
//             owner, signer.addr, pauser, denier, marketplace, mana, factories, primarySalesAllowed, secondarySalesAllowed, maxManaTransferPerHour
//         );
//     }

//     function test_SetUpState() public view {
//         assertTrue(creditManager.hasRole(creditManager.DEFAULT_ADMIN_ROLE(), owner));
//         assertTrue(creditManager.hasRole(creditManager.SIGNER_ROLE(), signer.addr));
//         assertTrue(creditManager.hasRole(creditManager.PAUSER_ROLE(), pauser));
//         assertTrue(creditManager.hasRole(creditManager.PAUSER_ROLE(), owner));
//         assertTrue(creditManager.hasRole(creditManager.DENIER_ROLE(), denier));
//         assertTrue(creditManager.hasRole(creditManager.DENIER_ROLE(), owner));
//         assertEq(address(creditManager.marketplace()), address(marketplace));
//         assertEq(address(creditManager.mana()), address(mana));
//         assertEq(address(creditManager.factories(0)), address(factories[0]));
//         assertEq(address(creditManager.factories(1)), address(factories[1]));
//         assertTrue(creditManager.primarySalesAllowed());
//         assertTrue(creditManager.secondarySalesAllowed());
//         assertEq(creditManager.maxManaTransferPerHour(), maxManaTransferPerHour);
//         assertEq(creditManager.manaTransferredThisHour(), 0);
//         assertEq(creditManager.hourOfLastManaTransfer(), 0);
//     }
// }
