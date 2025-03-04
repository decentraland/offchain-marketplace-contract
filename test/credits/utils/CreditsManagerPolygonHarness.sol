// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CreditsManagerPolygon} from "src/credits/CreditsManagerPolygon.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";

contract CreditsManagerPolygonHarness is CreditsManagerPolygon {
    constructor(
        Roles memory _roles,
        uint256 _maxManaCreditedPerHour,
        bool _primarySalesAllowed,
        bool _secondarySalesAllowed,
        bool _bidsAllowed,
        IERC20 _mana,
        address _marketplace,
        address _legacyMarketplace,
        address _collectionStore,
        ICollectionFactory _collectionFactory,
        ICollectionFactory _collectionFactoryV3
    )
        CreditsManagerPolygon(
            _roles,
            _maxManaCreditedPerHour,
            _primarySalesAllowed,
            _secondarySalesAllowed,
            _bidsAllowed,
            _mana,
            _marketplace,
            _legacyMarketplace,
            _collectionStore,
            _collectionFactory,
            _collectionFactoryV3
        )
    {}

    function updateTempBidCreditsSignaturesHash(bytes32 _tempBidCreditsSignaturesHash) external {
        tempBidCreditsSignaturesHash = _tempBidCreditsSignaturesHash;
    }

    function updateTempMaxUncreditedValue(uint256 _tempMaxUncreditedValue) external {
        tempMaxUncreditedValue = _tempMaxUncreditedValue;
    }

    function updateTempMaxCreditedValue(uint256 _tempMaxCreditedValue) external {
        tempMaxCreditedValue = _tempMaxCreditedValue;
    }
}
