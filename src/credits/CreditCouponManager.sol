// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {MarketplaceWithCouponManager} from "src/marketplace/MarketplaceWithCouponManager.sol";
import {MarketplaceTypes} from "src/marketplace/MarketplaceTypes.sol";
import {CouponTypes} from "src/coupons/CouponTypes.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";
import {NativeMetaTransaction} from "src/common/NativeMetaTransaction.sol";
import {EIP712} from "src/common/EIP712.sol";

contract CreditCouponManager is MarketplaceTypes, CouponTypes, ReentrancyGuard, Pausable, AccessControl, NativeMetaTransaction {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant DENIER_ROLE = keccak256("DENIER_ROLE");

    struct CreditCoupon {
        uint256 amount;
        uint256 expiration;
        bytes32 salt;
        bytes signature;
    }

    MarketplaceWithCouponManager public immutable marketplace;

    IERC20 public immutable mana;

    ICollectionFactory[] public factories;

    mapping(bytes32 => uint256) public spentCouponCredits;

    mapping(address => bool) public denyList;

    constructor(address _owner, address _signer, address _pauser, address _denier, MarketplaceWithCouponManager _marketplace, IERC20 _mana, ICollectionFactory[] memory _factories) EIP712("CreditCouponManager", "1.0.0") {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(SIGNER_ROLE, _signer);
        _grantRole(PAUSER_ROLE, _pauser);
        _grantRole(PAUSER_ROLE, _owner);
        _grantRole(DENIER_ROLE, _denier);
        _grantRole(DENIER_ROLE, _owner);

        marketplace = _marketplace;
        mana = _mana;
        factories = _factories;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function deny(address[] calldata _user) external onlyRole(DENIER_ROLE) {
        for (uint256 i = 0; i < _user.length; i++) {
            denyList[_user[i]] = true;
        }
    }

    function undeny(address[] calldata _user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < _user.length; i++) {
            denyList[_user[i]] = false;
        }
    }

    function accept(Trade[] calldata _trades, CreditCoupon[] calldata _creditCoupons) external nonReentrant whenNotPaused {
        address sender = _msgSender();

        if (denyList[sender]) {
            revert("Sender is denied");
        }

        _validateTrades(_trades);

        uint256 oldBalance = mana.balanceOf(address(this));

        marketplace.accept(_trades);

        uint256 newBalance = mana.balanceOf(address(this));

        uint256 totalManaTransferred = oldBalance - newBalance;

        if (totalManaTransferred == 0) {
            revert("No mana was transferred");
        }

        uint256 totalCreditSpent = 0;

        if (_creditCoupons.length == 0) {
            revert("Invalid coupons length");
        }

        for (uint256 i = 0; i < _creditCoupons.length; i++) {
            CreditCoupon calldata creditCoupon = _creditCoupons[i];

            _validateCoupon(creditCoupon);

            bytes32 couponSigHash = keccak256(creditCoupon.signature);

            uint256 totalManaTransferredAndCreditSpentDiff = totalManaTransferred - totalCreditSpent;

            uint256 spendableCredit = creditCoupon.amount - spentCouponCredits[couponSigHash];

            if (spendableCredit == 0) {
                revert("Coupon has been fully spent");
            }

            uint256 creditToBeSpent = totalManaTransferredAndCreditSpentDiff > spendableCredit ? spendableCredit : totalManaTransferredAndCreditSpentDiff;

            totalCreditSpent += creditToBeSpent;

            spentCouponCredits[couponSigHash] += creditToBeSpent;
        }

        mana.safeTransfer(sender, totalCreditSpent);

        mana.safeTransferFrom(sender, address(this), totalManaTransferred - totalCreditSpent);
    }

    function _validateTrades(Trade[] calldata _trades) private view {
        if (_trades.length == 0) {
            revert("Invalid trades length");
        }

        for (uint256 i = 0; i < _trades.length; i++) {
            Trade calldata trade = _trades[i];

            if (trade.sent.length < 1 || trade.received.length != 1) {
                revert("Invalid assets length");
            }

            if (trade.received[0].contractAddress != address(mana)) {
                revert("Invalid received asset");
            }

            for (uint256 j = 0; j < trade.sent.length; j++) {
                Asset calldata asset = trade.sent[j];

                if (!_isDecentralandItem(asset.contractAddress) || asset.beneficiary == address(0)) {
                    revert("Invalid sent asset");
                }
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

    function _validateCoupon(CreditCoupon calldata _coupon) private view {
        if (_coupon.amount == 0) {
            revert("Invalid coupon amount");
        }

        if (block.timestamp > _coupon.expiration) {
            revert("Coupon has expired");
        }

        bytes32 couponHash = keccak256(abi.encode(_msgSender(), _coupon.amount, _coupon.expiration, _coupon.salt, address(this), block.chainid));

        if (!hasRole(SIGNER_ROLE, couponHash.recover(_coupon.signature))) {
            revert("Invalid coupon signature");
        }
    }

    function _msgSender() internal view override returns (address) {
        return _getMsgSender();
    }
}
