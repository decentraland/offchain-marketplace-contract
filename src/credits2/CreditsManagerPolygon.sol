// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {CreditsManager} from "./CreditsManager.sol";
import {IMarketplace, Trade} from "./interfaces/IMarketplace.sol";
import {ICollectionStore} from "./interfaces/ICollectionStore.sol";
import {ILegacyMarketplace} from "./interfaces/ILegacyMarketplace.sol";
import {ICollectionFactory} from "./interfaces/ICollectionFactory.sol";
import {NativeMetaTransaction, EIP712} from "../common/NativeMetaTransaction.sol";

contract CreditsManagerPolygon is CreditsManager, NativeMetaTransaction {
    address public immutable marketplace;
    address public immutable legacyMarketplace;
    address public immutable collectionStore;

    ICollectionFactory public immutable collectionFactory;
    ICollectionFactory public immutable collectionFactoryV3;

    error NotDecentralandCollection(address _contractAddress);
    error ExternalCallFailed(ExternalCall _externalCall);
    error InvalidBeneficiary();
    error InvalidTrade(Trade _trade);

    constructor(
        Init memory _init,
        address _marketplace,
        address _legacyMarketplace,
        address _collectionStore,
        ICollectionFactory _collectionFactory,
        ICollectionFactory _collectionFactoryV3
    ) CreditsManager(_init) EIP712("CreditsManagerPolygon", "1.0.0") {
        marketplace = _marketplace;
        legacyMarketplace = _legacyMarketplace;
        collectionStore = _collectionStore;
        collectionFactory = _collectionFactory;
        collectionFactoryV3 = _collectionFactoryV3;

        _allowCall(marketplace, IMarketplace.accept.selector, true);
        _allowCall(marketplace, IMarketplace.acceptWithCoupon.selector, true);
        _allowCall(collectionStore, ICollectionStore.buy.selector, true);
        _allowCall(legacyMarketplace, ILegacyMarketplace.safeExecuteOrder.selector, true);
        _allowCall(legacyMarketplace, ILegacyMarketplace.executeOrder.selector, true);
    }

    function _executeExternalCall(ExternalCall calldata _externalCall) internal override {
        if (_externalCall.target == legacyMarketplace) {
            (address contractAddress) = abi.decode(_externalCall.data, (address));

            _verifyDecentralandCollection(contractAddress);
        }

        if (_externalCall.target == marketplace) {
            Trade[] memory trades = abi.decode(_externalCall.data, (Trade[]));

            for (uint256 i = 0; i < trades.length; i++) {
                Trade memory trade = trades[i];

                if (trade.received.length == 1 && trade.received[0].contractAddress == address(mana)) {
                    for (uint256 j = 0; j < trade.sent.length; j++) {
                        _verifyDecentralandCollection(trade.sent[j].contractAddress);

                        if (trade.sent[j].beneficiary == address(0)) {
                            revert InvalidBeneficiary();
                        }
                    }
                } else {
                    revert InvalidTrade(trade);
                }
            }
        }

        (bool success,) = _externalCall.target.call(_externalCall.data);

        if (!success) {
            revert ExternalCallFailed(_externalCall);
        }

        if (_externalCall.target == legacyMarketplace) {
            (address contractAddress, uint256 tokenId) = abi.decode(_externalCall.data, (address, uint256));

            IERC721(contractAddress).safeTransferFrom(address(this), _msgSender(), tokenId);
        }
    }

    function _verifyDecentralandCollection(address _contractAddress) internal view {
        if (!collectionFactory.isCollectionFromFactory(_contractAddress) && !collectionFactoryV3.isCollectionFromFactory(_contractAddress)) {
            revert NotDecentralandCollection(_contractAddress);
        }
    }

    function _msgSender() internal view override returns (address) {
        return _getMsgSender();
    }
}
