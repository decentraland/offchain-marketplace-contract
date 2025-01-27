// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CreditManager} from "src/credits/CreditManager.sol";
import {DecentralandMarketplacePolygon} from "src/marketplace/DecentralandMarketplacePolygon.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";

contract CreditManagerHarness is CreditManager {
    constructor(
        address _owner,
        address _signer,
        address _pauser,
        address _denier,
        DecentralandMarketplacePolygon _marketplace,
        IERC20 _mana,
        ICollectionFactory[] memory _factories,
        AllowedSales memory _allowedSales,
        uint256 _maxManaTransferPerHour
    ) CreditManager(_owner, _signer, _pauser, _denier, _marketplace, _mana, _factories, _allowedSales, _maxManaTransferPerHour) {}
}

contract CreditManagerTest is Test {
    
}
