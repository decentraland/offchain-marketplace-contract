// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CreditManagerBase} from "src/credits/CreditManagerBase.sol";
import {IMarketplace} from "src/credits/interfaces/IMarketplace.sol";

abstract contract MarketplaceStrategy is CreditManagerBase {
    IMarketplace public immutable marketplace;

    constructor(IMarketplace _marketplace) {
        marketplace = _marketplace;
    }

    function executeMarketplaceExecuteOrder(
        address[] calldata _nftAddress,
        uint256[] calldata _assetId,
        uint256[] calldata _price,
        Credit[] calldata _credits
    ) external {
        _validateSecondarySalesAllowed();

        uint256 totalManaToTransfer;

        for (uint256 i = 0; i < _price.length; i++) {
            totalManaToTransfer += _price[i];
        }

        _consumeCredits(_credits, totalManaToTransfer);

        mana.approve(address(marketplace), totalManaToTransfer);

        uint256 balanceBefore = mana.balanceOf(address(this));

        for (uint256 i = 0; i < _nftAddress.length; i++) {
            marketplace.executeOrder(_nftAddress[i], _assetId[i], _price[i]);
        }

        _validateResultingBalance(balanceBefore, totalManaToTransfer);
    }
}
