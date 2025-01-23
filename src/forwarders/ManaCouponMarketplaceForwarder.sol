// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {DecentralandMarketplacePolygon} from "src/marketplace/DecentralandMarketplacePolygon.sol";

contract ManaCouponMarketplaceForwarder is AccessControl, Pausable {
    using ECDSA for bytes32;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    struct ManaCoupon {
        uint256 amount;
        uint256 expiration;
        uint256 effective;
        bytes32 salt;
        address beneficiary;
        bytes signature;
    }

    struct MetaTx {
        address user;
        bytes data;
    }

    mapping(bytes32 => uint256) public amountUsedFromCoupon;
    DecentralandMarketplacePolygon public marketplace;

    error InvalidSigner(address _signer);
    error CouponExpired(uint256 _currentTime);
    error CouponIneffective(uint256 _currentTime);
    error InvalidSelector(bytes4 _selector);
    error InvalidMetaTxUser(address _user);
    error MarketplaceCallFailed();

    constructor(address _owner, address _pauser, address _signer, DecentralandMarketplacePolygon _marketplace) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(PAUSER_ROLE, _owner);
        _grantRole(PAUSER_ROLE, _pauser);
        _grantRole(SIGNER_ROLE, _signer);

        marketplace = _marketplace;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function forward(ManaCoupon calldata _coupon, bytes calldata _executeMetaTx) external whenNotPaused {
        bytes32 hashedCoupon = keccak256(abi.encode(_coupon.amount, _coupon.expiration, _coupon.effective, _coupon.salt));
        address signer = hashedCoupon.recover(_coupon.signature);

        if (!hasRole(SIGNER_ROLE, signer)) {
            revert InvalidSigner(signer);
        }

        if (_coupon.expiration < block.timestamp) {
            revert CouponExpired(block.timestamp);
        }

        if (_coupon.effective > block.timestamp) {
            revert CouponIneffective(block.timestamp);
        }

        MetaTx memory metaTx = _extractMetaTx(_executeMetaTx);

        if (metaTx.user != _coupon.beneficiary) {
            revert InvalidMetaTxUser(metaTx.user);
        }

        amountUsedFromCoupon[keccak256(_coupon.signature)] += _coupon.amount;

        (bool success,) = address(marketplace).call(_executeMetaTx);

        if (!success) {
            revert MarketplaceCallFailed();
        }
    }

    function _extractMetaTx(bytes memory _bytes) private view returns (MetaTx memory metaTx) {
        (bytes4 selector, bytes memory data) = _separateSelectorAndData(_bytes);

        if (selector != marketplace.executeMetaTransaction.selector) {
            revert InvalidSelector(selector);
        }

        (metaTx.user, metaTx.data) = abi.decode(data, (address, bytes));
    }

    function _separateSelectorAndData(bytes memory _bytes) private pure returns (bytes4 selector, bytes memory data) {
        selector = bytes4(_bytes);

        uint256 dataLength = _bytes.length - 4;

        data = new bytes(dataLength);

        for (uint256 i = 0; i < dataLength; i++) {
            data[i] = _bytes[4 + i];
        }
    }
}
