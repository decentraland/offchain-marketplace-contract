// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MarketplaceWithCouponManager} from "src/marketplace/MarketplaceWithCouponManager.sol";
import {MarketplaceTypes} from "src/marketplace/MarketplaceTypes.sol";
import {CouponTypes} from "src/coupons/CouponTypes.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";

contract CreditManager is MarketplaceTypes, CouponTypes {
    uint256 private constant TRADE_TYPE_LISTING = 1;
    uint256 private constant TRADE_TYPE_BID = 2;

    struct Credit {
        uint256 amount;
        uint256 expiration;
        bytes32 salt;
        bytes signature;
    }

    MarketplaceWithCouponManager public immutable marketplace;

    IERC20 public immutable mana;

    ICollectionFactory[] public factories;

    mapping(bytes32 => uint256) public manaUsedFromCredits;

    constructor(MarketplaceWithCouponManager _marketplace, IERC20 _mana, ICollectionFactory[] memory _factories) {
        marketplace = _marketplace;
        mana = _mana;
        factories = _factories;
    }

    function accept(Trade[] calldata _trades, Credit[][] calldata _credits) external {
        marketplace.accept(_trades);
    }

    function acceptWithCoupon(Trade[] calldata _trades, Coupon[] calldata _coupons, Credit[][] calldata _credits) external {
        marketplace.acceptWithCoupon(_trades, _coupons);
    }

    function _tradeType(Trade calldata _trade) private view returns (uint256 tradeType) {
        for (uint256 i = 0; i < _trade.sent.length; i++) {
            Asset calldata asset = _trade.sent[i];

            bool isMana = asset.contractAddress == address(mana);
            bool isDecentralandItem = _isDecentralandItem(asset.contractAddress);

            if (i == 0) {
                if (isMana) {
                    tradeType = TRADE_TYPE_BID;
                } else if (isDecentralandItem) {
                    tradeType = TRADE_TYPE_LISTING;
                }
            } else if (tradeType == 0 || isMana || tradeType == TRADE_TYPE_BID && isDecentralandItem || !isDecentralandItem) {
                revert("Invalid asset");
            }
        }

        for (uint256 i = 0; i < _trade.received.length; i++) {
            Asset calldata asset = _trade.received[i];

            bool isMana = asset.contractAddress == address(mana);
            bool isDecentralandItem = _isDecentralandItem(asset.contractAddress);

            if (tradeType == TRADE_TYPE_BID && !isDecentralandItem || tradeType == TRADE_TYPE_LISTING && !isMana || tradeType == TRADE_TYPE_LISTING && _trade.received.length > 1) {
                revert("Invalid asset");
            }
        }
    }

    function _isDecentralandItem(address _contractAddress) private view returns (bool) {
        for (uint256 i = 0; i < factories.length; i++) {
            if (factories[i].isCollectionFromFactory(_contractAddress)) {
                return true;
            }
        }

        return false;
    }
}
