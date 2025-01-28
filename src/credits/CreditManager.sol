// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {DecentralandMarketplacePolygon} from "src/marketplace/DecentralandMarketplacePolygon.sol";
import {MarketplaceTypes} from "src/marketplace/MarketplaceTypes.sol";
import {CouponTypes} from "src/coupons/CouponTypes.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";
import {NativeMetaTransaction} from "src/common/NativeMetaTransaction.sol";
import {EIP712} from "src/common/EIP712.sol";
import {AggregatorHelper} from "src/marketplace/AggregatorHelper.sol";

/// @notice Enables users to use off-chain signed credit instead of spending mana for trades.
contract CreditManager is MarketplaceTypes, CouponTypes, ReentrancyGuard, Pausable, AccessControl, NativeMetaTransaction, AggregatorHelper {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /// @notice The role that can sign credits.
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    /// @notice The role that can pause the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice The role that can deny users from using credits.
    bytes32 public constant DENIER_ROLE = keccak256("DENIER_ROLE");

    /// @notice The schema of the Credit type.
    struct Credit {
        uint256 amount; // The amount of mana that the credit is worth.
        uint256 expiration; // The expiration timestamp of the credit.
        bytes32 salt; // The salt used to generate a unique the credit signature.
        bytes signature; // The signature of the credit.
    }

    /// @notice The Decentraland Marketplace contract.
    DecentralandMarketplacePolygon public immutable marketplace;

    /// @notice The MANA token contract.
    IERC20 public immutable mana;

    /// @notice The collection factories used to check that a contract address is a Decentraland Item/NFT.
    ICollectionFactory[] public factories;

    /// @notice How many credits have been spent from a particular credit.
    /// The key is the keccak256 hash of the credit signature.
    mapping(bytes32 => uint256) public spentCredits;

    /// @notice The users that have been denied from using credits.
    mapping(address => bool) public denyList;

    /// @notice Whether using credits for primary sales is allowed.
    bool public primarySalesAllowed;

    /// @notice Whether using credits for secondary sales is allowed.
    bool public secondarySalesAllowed;

    /// @notice Maximum amount of mana that can be transferred out of the contract per hour.
    uint256 public maxManaTransferPerHour;

    /// @notice How much mana has been transferred out of the contract this hour.
    uint256 public manaTransferredThisHour;

    /// @notice The hour of the last mana transfer.
    uint256 public hourOfLastManaTransfer;

    event AllowedSalesUpdated(address _sender, bool _primary, bool _secondary);
    event MaxManaTransferPerHourUpdated(address _sender, uint256 _maxManaTransferPerHour);
    event DenyListUpdated(address _sender, address _user, bool _value);

    constructor(
        address _owner, // The address that can set other roles as well as operate the most critical functions.
        address _signer, // The address that can sign credits.
        address _pauser, // The address that can pause the contract.
        address _denier, // The address that can deny users from using credits.
        DecentralandMarketplacePolygon _marketplace, // The Decentraland Marketplace contract.
        IERC20 _mana, // The MANA token contract.
        ICollectionFactory[] memory _factories, // The collection factories used to check that a contract address is a Decentraland Item/NFT.
        bool _primarySalesAllowed, // Whether using credits for primary sales is allowed.
        bool _secondarySalesAllowed, // Whether using credits for secondary sales is allowed.
        uint256 _maxManaTransferPerHour
    ) EIP712("CreditManager", "1.0.0") {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(SIGNER_ROLE, _signer);
        _grantRole(PAUSER_ROLE, _pauser);
        _grantRole(PAUSER_ROLE, _owner);
        _grantRole(DENIER_ROLE, _denier);
        _grantRole(DENIER_ROLE, _owner);

        marketplace = _marketplace;
        mana = _mana;
        factories = _factories;

        _updateAllowedSales(_primarySalesAllowed, _secondarySalesAllowed);
        _updateMaxManaTransferPerHour(_maxManaTransferPerHour);
    }

    function updateAllowedSales(bool _primary, bool _secondary) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateAllowedSales(_primary, _secondary);
    }

    function updateMaxManaTransferPerHour(uint256 _maxManaTransferPerHour) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateMaxManaTransferPerHour(_maxManaTransferPerHour);
    }

    function updateDenyList(address[] calldata _users, bool[] calldata _values) external {
        address sender = _msgSender();

        for (uint256 i = 0; i < _users.length; i++) {
            bool value = _values[i];

            if (!hasRole(value ? DENIER_ROLE : DEFAULT_ADMIN_ROLE, sender)) {
                revert("Sender is not allowed");
            }

            _updateDenyList(_users[i], value);
        }
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function withdraw(uint256 _amount, address _beneficiary) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mana.safeTransfer(_beneficiary, _amount);
    }

    function accept(Trade[] calldata _trades, Coupon[] calldata _coupons, Credit[] calldata _credits) external nonReentrant whenNotPaused {
        address sender = _msgSender();

        if (denyList[sender]) {
            revert("Sender is denied");
        }

        uint256 expectedManaTransfer = _validateTrades(_trades);

        mana.approve(address(marketplace), expectedManaTransfer);

        uint256 manaTransferred = _executeMarketplaceCall(_trades, _coupons);

        _validateManaTransferLimit(manaTransferred);

        mana.approve(address(marketplace), 0);

        uint256 manaCredited = _handleCredits(_credits, manaTransferred);

        mana.safeTransfer(sender, manaCredited);

        mana.safeTransferFrom(sender, address(this), manaTransferred - manaCredited);
    }

    function _updateAllowedSales(bool _primary, bool _secondary) private {
        primarySalesAllowed = _primary;
        secondarySalesAllowed = _secondary;

        emit AllowedSalesUpdated(_msgSender(), _primary, _secondary);
    }

    function _updateMaxManaTransferPerHour(uint256 _maxManaTransferPerHour) private {
        maxManaTransferPerHour = _maxManaTransferPerHour;

        emit MaxManaTransferPerHourUpdated(_msgSender(), _maxManaTransferPerHour);
    }

    function _updateDenyList(address _user, bool _value) private {
        denyList[_user] = _value;

        emit DenyListUpdated(_msgSender(), _user, _value);
    }

    function _validateTrades(Trade[] calldata _trades) private view returns (uint256 expectedManaTransfer) {
        if (_trades.length == 0) {
            revert("Invalid trades length");
        }

        int256 manaUsdRate;

        for (uint256 i = 0; i < _trades.length; i++) {
            Asset[] calldata sent = _trades[i].sent;
            Asset[] calldata received = _trades[i].received;

            if (sent.length < 1 || received.length != 1) {
                revert("Invalid assets length");
            }

            if (received[0].assetType == marketplace.ASSET_TYPE_ERC20()) {
                if (received[0].contractAddress != address(mana)) {
                    revert("Invalid received asset contract address");
                }

                expectedManaTransfer += received[0].value;
            } else if (received[0].assetType == marketplace.ASSET_TYPE_USD_PEGGED_MANA()) {
                if (manaUsdRate == 0) {
                    manaUsdRate = _getRateFromAggregator(marketplace.manaUsdAggregator(), marketplace.manaUsdAggregatorTolerance());
                }

                expectedManaTransfer += received[0].value * 1e18 / uint256(manaUsdRate);
            } else {
                revert("Invalid received asset type");
            }

            for (uint256 j = 0; j < sent.length; j++) {
                Asset calldata asset = sent[j];

                if (asset.assetType == marketplace.ASSET_TYPE_COLLECTION_ITEM()) {
                    if (!primarySalesAllowed) {
                        revert("Primary sales are not allowed");
                    }
                } else if (asset.assetType == marketplace.ASSET_TYPE_ERC721()) {
                    if (!secondarySalesAllowed) {
                        revert("Secondary sales are not allowed");
                    }
                } else {
                    revert("Invalid sent asset type");
                }

                if (!_isDecentralandItem(asset.contractAddress)) {
                    revert("Not a decentraland item");
                }

                if (asset.beneficiary == address(0)) {
                    revert("Invalid asset beneficiary");
                }
            }
        }
    }

    function _executeMarketplaceCall(Trade[] calldata _trades, Coupon[] calldata _coupons) private returns (uint256 manaTransferred) {
        uint256 originalBalance = mana.balanceOf(address(this));

        if (_coupons.length > 0) {
            marketplace.acceptWithCoupon(_trades, _coupons);
        } else {
            marketplace.accept(_trades);
        }

        uint256 currentBalance = mana.balanceOf(address(this));

        manaTransferred = originalBalance - currentBalance;

        if (manaTransferred == 0) {
            revert("No mana was transferred");
        }
    }

    function _validateManaTransferLimit(uint256 _manaTransferred) private {
        uint256 currentHour = block.timestamp / 1 hours;

        if (currentHour != hourOfLastManaTransfer) {
            manaTransferredThisHour = 0;
            hourOfLastManaTransfer = currentHour;
        }

        if (manaTransferredThisHour + _manaTransferred > maxManaTransferPerHour) {
            revert("Max mana transfer per hour exceeded");
        }

        manaTransferredThisHour += _manaTransferred;
    }

    function _handleCredits(Credit[] calldata _credits, uint256 manaTransferred) private returns (uint256 creditedMana) {
        if (_credits.length == 0) {
            revert("Invalid credits length");
        }

        for (uint256 i = 0; i < _credits.length; i++) {
            Credit calldata credit = _credits[i];

            uint256 spendableCreditAmount = _validateCredit(credit);

            uint256 manaTransferredAndCreditedManaDiff = manaTransferred - creditedMana;

            uint256 spentCreditAmount =
                manaTransferredAndCreditedManaDiff > spendableCreditAmount ? spendableCreditAmount : manaTransferredAndCreditedManaDiff;

            creditedMana += spentCreditAmount;

            spentCredits[keccak256(credit.signature)] += spentCreditAmount;
        }
    }

    function _validateCredit(Credit calldata _credit) private view returns (uint256 spendableCreditAmount) {
        if (_credit.amount == 0) {
            revert("Invalid credit amount");
        }

        if (block.timestamp > _credit.expiration) {
            revert("Credit has expired");
        }

        bytes32 digest = keccak256(abi.encode(_msgSender(), _credit.amount, _credit.expiration, _credit.salt, address(this), block.chainid));

        if (!hasRole(SIGNER_ROLE, digest.recover(_credit.signature))) {
            revert("Invalid credit signature");
        }

        spendableCreditAmount = _credit.amount - spentCredits[keccak256(_credit.signature)];

        if (spendableCreditAmount == 0) {
            revert("Credit has been spent");
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

    function _msgSender() internal view override returns (address) {
        return _getMsgSender();
    }
}
