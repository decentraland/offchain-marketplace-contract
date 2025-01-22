// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {DecentralandMarketplacePolygon} from "src/marketplace/DecentralandMarketplacePolygon.sol";
import {MarketplaceTypes} from "src/marketplace/MarketplaceTypes.sol";
import {CouponTypes} from "src/coupons/CouponTypes.sol";
import {DecentralandMarketplacePolygonAssetTypes} from "src/marketplace/DecentralandMarketplacePolygonAssetTypes.sol";

contract ManaCouponMarketplaceForwarderPolygon is AccessControl, MarketplaceTypes, CouponTypes, DecentralandMarketplacePolygonAssetTypes {
    using ECDSA for bytes32;

    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    DecentralandMarketplacePolygon public immutable marketplace;
    IERC20 public immutable mana;
    mapping(bytes32 => uint256) public couponSpending;

    struct ManaCoupon {
        uint256 expiration;
        uint256 effective;
        uint256 salt;
        uint256 amount;
        bytes signature;
    }

    struct MetaTx {
        address userAddress;
        bytes functionData;
        bytes signature;
    }

    error InvalidDataSelector(bytes4 _selector);
    error InvalidMetaTxUser(address _beneficiary);
    error InvalidMetaTxFunctionDataSelector(bytes4 _selector);
    error MarketplaceCallFailed();
    error CouponExpired(uint256 _currentTime);
    error CouponIneffective(uint256 _currentTime);
    error InvalidSigner(address _signer);

    constructor(address _owner, address _caller, address _signer, address _pauser, DecentralandMarketplacePolygon _marketplace, IERC20 _mana) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(CALLER_ROLE, _caller);
        _grantRole(SIGNER_ROLE, _signer);
        _grantRole(PAUSER_ROLE, _pauser);

        marketplace = _marketplace;
        mana = _mana;
    }

    function forwardCall(address _beneficiary, ManaCoupon[][] calldata _coupons, bytes calldata _executeMetaTx) external onlyRole(CALLER_ROLE) {
        MetaTx memory metaTx = _extractMetaTx(_executeMetaTx);

        if (metaTx.userAddress != _beneficiary) {
            revert InvalidMetaTxUser(metaTx.userAddress);
        }

        Trade[] memory trades = _extractTrades(metaTx.functionData);

        for (uint256 i = 0; i < trades.length; i++) {
            _handleTrade(_beneficiary, trades[i], _coupons[i]);
        }

        (bool success,) = address(marketplace).call(_executeMetaTx);

        if (!success) {
            revert MarketplaceCallFailed();
        }
    }

    function _extractMetaTx(bytes memory _bytes) private view returns (MetaTx memory metaTx) {
        (bytes4 selector, bytes memory data) = _separateSelectorAndData(_bytes);

        if (selector != marketplace.executeMetaTransaction.selector) {
            revert InvalidDataSelector(selector);
        }

        (metaTx.userAddress, metaTx.functionData, metaTx.signature) = abi.decode(data, (address, bytes, bytes));
    }

    function _extractTrades(bytes memory _bytes) private view returns (Trade[] memory trades) {
        (bytes4 selector, bytes memory data) = _separateSelectorAndData(_bytes);

        if (selector != marketplace.accept.selector && selector != marketplace.acceptWithCoupon.selector) {
            revert InvalidMetaTxFunctionDataSelector(selector);
        }

        if (selector == marketplace.accept.selector) {
            (trades) = abi.decode(data, (Trade[]));
        } else {
            (trades,) = abi.decode(data, (Trade[], Coupon[]));
        }
    }

    function _separateSelectorAndData(bytes memory _bytes) private pure returns (bytes4 selector, bytes memory data) {
        selector = bytes4(_bytes);

        uint256 dataLength = _bytes.length - 4;

        data = new bytes(dataLength);

        for (uint256 i = 0; i < dataLength; i++) {
            data[i] = _bytes[4 + i];
        }
    }

    function _handleTrade(address _beneficiary, Trade memory _trade, ManaCoupon[] memory _coupons) private {
        Asset[] memory received = _trade.received;

        uint256 totalManaAmountRequired;

        for (uint256 i = 0; i < received.length; i++) {
            if (received[i].assetType == ASSET_TYPE_ERC20 && received[i].contractAddress == address(mana)) {
                totalManaAmountRequired += received[i].value;
            }
        }

        uint256 totalManaFromCoupons;

        for (uint256 i = 0; i < _coupons.length; i++) {
            totalManaFromCoupons += _handleCoupon(_beneficiary, totalManaAmountRequired, totalManaFromCoupons, _coupons[i]);
        }

        mana.transfer(_beneficiary, totalManaFromCoupons);
    }

    function _handleCoupon(address _beneficiary, uint256 _totalManaRequired, uint256 _totalManaAccFromCoupons, ManaCoupon memory _coupon)
        private
        returns (uint256)
    {
        _verifyCoupon(_beneficiary, _coupon);

        bytes32 hashedSig = keccak256(_coupon.signature);

        uint256 toSpendFromCoupon = _coupon.amount - couponSpending[hashedSig];

        uint256 remainingToReachTotal = _totalManaRequired - _totalManaAccFromCoupons;

        if (remainingToReachTotal < toSpendFromCoupon) {
            toSpendFromCoupon = remainingToReachTotal;
        }

        couponSpending[hashedSig] += toSpendFromCoupon;

        return toSpendFromCoupon;
    }

    function _verifyCoupon(address _beneficiary, ManaCoupon memory _coupon) private view {
        if (_coupon.expiration < block.timestamp) {
            revert CouponExpired(block.timestamp);
        }

        if (_coupon.effective > block.timestamp) {
            revert CouponIneffective(block.timestamp);
        }

        bytes32 couponHash = keccak256(abi.encode(_beneficiary, _coupon.expiration, _coupon.effective, _coupon.salt, _coupon.amount));

        address signer = couponHash.recover(_coupon.signature);

        if (!hasRole(SIGNER_ROLE, signer)) {
            revert InvalidSigner(signer);
        }
    }
}
