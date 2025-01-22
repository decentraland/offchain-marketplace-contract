// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DecentralandMarketplacePolygon} from "src/marketplace/DecentralandMarketplacePolygon.sol";
import {MarketplaceTypes} from "src/marketplace/MarketplaceTypes.sol";
import {CouponTypes} from "src/coupons/CouponTypes.sol";
import {DecentralandMarketplacePolygonAssetTypes} from "src/marketplace/DecentralandMarketplacePolygonAssetTypes.sol";

contract ManaCouponMarketplaceForwarderPolygon is AccessControl, MarketplaceTypes, CouponTypes, DecentralandMarketplacePolygonAssetTypes {
    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    DecentralandMarketplacePolygon public immutable marketplace;
    IERC20 public immutable mana;
    mapping(bytes32 => uint256) public couponSpending;

    struct ManaCoupon {
        uint256 expiration;
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

    constructor(address _owner, address _caller, address _signer, address _pauser, DecentralandMarketplacePolygon _marketplace, IERC20 _mana) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(CALLER_ROLE, _caller);
        _grantRole(SIGNER_ROLE, _signer);
        _grantRole(PAUSER_ROLE, _pauser);

        marketplace = _marketplace;
        mana = _mana;
    }

    function forwardCall(address _beneficiary, ManaCoupon[][] calldata _coupons, bytes calldata _executeMetaTx) external onlyRole(CALLER_ROLE) {
        MetaTx memory metaTx = extractMetaTx(_executeMetaTx);

        if (metaTx.userAddress != _beneficiary) {
            revert InvalidMetaTxUser(metaTx.userAddress);
        }

        Trade[] memory trades = extractTrades(metaTx.functionData);

        for (uint256 i = 0; i < trades.length; i++) {
            ManaCoupon[] calldata coupons = _coupons[i];

            Asset[] memory received = trades[i].received;

            uint256 totalManaAmountRequired;

            for (uint256 j = 0; j < received.length; j++) {
                if (received[j].assetType == ASSET_TYPE_ERC20 && received[j].contractAddress == address(mana)) {
                    totalManaAmountRequired += received[j].value;
                }
            }

            uint256 totalManaCredits;

            for (uint256 j = 0; j < coupons.length; j++) {
                bytes32 hashedSig = keccak256(coupons[j].signature);

                uint256 toSpendFromCoupon = coupons[j].amount - couponSpending[hashedSig];

                uint256 remainingToReachTotal = totalManaAmountRequired - totalManaCredits;

                if (remainingToReachTotal < toSpendFromCoupon) {
                    toSpendFromCoupon = remainingToReachTotal;
                }

                totalManaCredits += toSpendFromCoupon;

                couponSpending[hashedSig] -= toSpendFromCoupon;
            }

            mana.transfer(_beneficiary, totalManaCredits);
        }

        (bool success,) = address(marketplace).call(_executeMetaTx);

        if (!success) {
            revert MarketplaceCallFailed();
        }
    }

    function separateSelectorAndData(bytes memory _bytes) private pure returns (bytes4 selector, bytes memory data) {
        selector = bytes4(_bytes);

        uint256 dataLength = _bytes.length - 4;

        data = new bytes(dataLength);

        for (uint256 i = 0; i < dataLength; i++) {
            data[i] = _bytes[4 + i];
        }
    }

    function extractMetaTx(bytes memory _bytes) private view returns (MetaTx memory metaTx) {
        (bytes4 selector, bytes memory data) = separateSelectorAndData(_bytes);

        if (selector != marketplace.executeMetaTransaction.selector) {
            revert InvalidDataSelector(selector);
        }

        (metaTx.userAddress, metaTx.functionData, metaTx.signature) = abi.decode(data, (address, bytes, bytes));
    }

    function extractTrades(bytes memory _bytes) private view returns (Trade[] memory trades) {
        (bytes4 selector, bytes memory data) = separateSelectorAndData(_bytes);

        if (selector != marketplace.accept.selector && selector != marketplace.acceptWithCoupon.selector) {
            revert InvalidMetaTxFunctionDataSelector(selector);
        }

        if (selector == marketplace.accept.selector) {
            (trades) = abi.decode(data, (Trade[]));
        } else {
            (trades,) = abi.decode(data, (Trade[], Coupon[]));
        }
    }
}
