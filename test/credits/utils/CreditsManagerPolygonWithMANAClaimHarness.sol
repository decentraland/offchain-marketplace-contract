// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {CreditsManagerPolygonWithMANAClaim} from "src/credits/CreditsManagerPolygonWithMANAClaim.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";
import {MarketplaceTypesHashing} from "src/marketplace/MarketplaceTypesHashing.sol";
import {IMarketplace} from "src/credits/interfaces/IMarketplace.sol";
import {MarketplaceTypes} from "src/marketplace/MarketplaceTypes.sol";

contract TestTradeHashing is MarketplaceTypesHashing {
    function hashTrade(IMarketplace.Trade calldata _trade) external view returns (bytes32) {
        bytes memory encodedTrade = abi.encode(_trade);
        MarketplaceTypes.Trade memory decodedTrade = abi.decode(encodedTrade, (MarketplaceTypes.Trade));
        return TestTradeHashing(address(this)).toCalldata(decodedTrade);
    }

    function toCalldata(MarketplaceTypes.Trade calldata _trade) external pure returns (bytes32) {
        return _hashTrade(_trade);
    }
}

contract CreditsManagerPolygonWithMANAClaimHarness is CreditsManagerPolygonWithMANAClaim {
    TestTradeHashing private testTradeHashing;

    constructor(
        Roles memory _roles,
        uint256 _maxManaCreditedPerHour,
        bool _primarySalesAllowed,
        bool _secondarySalesAllowed,
        IERC20 _mana,
        address _marketplace,
        address _legacyMarketplace,
        address _collectionStore,
        ICollectionFactory _collectionFactory,
        ICollectionFactory _collectionFactoryV3
    )
        CreditsManagerPolygonWithMANAClaim(
            _roles,
            _maxManaCreditedPerHour,
            _primarySalesAllowed,
            _secondarySalesAllowed,
            _mana,
            _marketplace,
            _legacyMarketplace,
            _collectionStore,
            _collectionFactory,
            _collectionFactoryV3
        )
    {
        testTradeHashing = new TestTradeHashing();
    }

    function tradeToTypedHashData(IMarketplace.Trade calldata _trade, address _marketplace) external view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                0x36c25de3e541d5d970f66e4210d728721220fff5c077cc6cd008b3a0c62adab7,
                keccak256(bytes("DecentralandMarketplacePolygon")),
                keccak256(bytes("1.0.0")),
                _marketplace,
                block.chainid
            )
        );

        bytes32 structHash = testTradeHashing.hashTrade(_trade);

        return MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
    }

    function metaTxToTypedHashData(address _userAddress, bytes calldata _functionData) external view returns (bytes32) {
        bytes32 domainSeparator = _domainSeparatorV4();

        bytes32 structHash = keccak256(
            abi.encode(
                0x01ecdc01065da9f72bf56a9def24a074b7ef512994beb776867cfbc664b5b959,
                CreditsManagerPolygonWithMANAClaim(address(this)).getNonce(_userAddress),
                _userAddress,
                keccak256(_functionData)
            )
        );

        return MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
    }
}
