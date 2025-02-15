// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

contract CreditManagerEthereumTest is Test {
    CreditManagerHarness private creditManager;

    function setUp() public {
        CollectionStoreStrategy.CollectionStoreStrategyInit memory collectionStoreStrategyInit =
            CollectionStoreStrategy.CollectionStoreStrategyInit({collectionStore: ICollectionStore(address(0))});

        MarketplaceStrategy.MarketplaceStrategyInit memory marketplaceStrategyInit =
            MarketplaceStrategy.MarketplaceStrategyInit({marketplace: IMarketplace(address(0))});

        OffchainMarketplaceStrategy.OffchainMarketplaceStrategyInit memory offchainMarketplaceStrategyInit = OffchainMarketplaceStrategy
            .OffchainMarketplaceStrategyInit({
            offchainMarketplace: MarketplaceWithCouponManager(address(0)),
            manaUsdRateProvider: IManaUsdRateProvider(address(0))
        });

        ArbitraryCallStrategy.ArbitraryCallStrategyInit memory arbitraryCallStrategyInit = ArbitraryCallStrategy.ArbitraryCallStrategyInit({
            arbitraryCallSigner: address(0),
            arbitraryCallRevoker: address(0),
            allowedTargets: new address[](0),
            allowedSelectors: new bytes4[](0)
        });

        CreditManagerBase.CreditManagerBaseInit memory creditManagerBaseInit = CreditManagerBase.CreditManagerBaseInit({
            owner: address(0),
            signer: address(0),
            pauser: address(0),
            denier: address(0),
            isPolygon: false,
            collectionFactory: ICollectionFactory(address(0)),
            collectionFactoryV3: ICollectionFactory(address(0)),
            land: address(0),
            estate: address(0),
            nameRegistry: address(0),
            mana: IERC20(address(0)),
            primarySalesAllowed: false,
            secondarySalesAllowed: false,
            maxManaTransferPerHour: 0
        });

        creditManager = new CreditManagerHarness(
            collectionStoreStrategyInit, marketplaceStrategyInit, offchainMarketplaceStrategyInit, arbitraryCallStrategyInit, creditManagerBaseInit
        );
    }
}
