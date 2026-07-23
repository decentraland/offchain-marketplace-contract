// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Verifications} from "src/common/Verifications.sol";
import {MarketplaceTypesHashing} from "src/marketplace/MarketplaceTypesHashing.sol";

/// @notice Main Marketplace abstract contract that contains the logic to validate and accept Trades.
abstract contract Marketplace is Verifications, MarketplaceTypesHashing, Pausable, ReentrancyGuard {
    /// @notice Trade ids that have been already used.
    /// Trade ids are composed by hashing:
    /// Salt + Caller + Received Assets (Contract Address + Value)
    mapping(bytes32 => bool) public usedTradeIds;

    /// @dev Emitted when a Trade is accepted.
    /// @param _signature keccak256 of the raw signature bytes (malleable; kept for indexing continuity).
    /// @param _tradeDigest The signed EIP-712 digest of the trade — the canonical, malleability-proof identifier;
    /// prefer it for off-chain correlation. Emitted explicitly because the `_trade` struct is post-modification
    /// and no longer hashes to the signed digest.
    event Traded(address indexed _caller, bytes32 indexed _signature, bytes32 indexed _tradeDigest, Trade _trade);

    error UsedTradeId();

    /// @notice Pauses the contract so no new trades can be accepted.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract to resume normal operations.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Revokes the signatures of all provided trades.
    /// The caller must be the signer of those trades.
    /// @param _trades The list of trade signatures to be canceled.
    function cancelSignature(Trade[] calldata _trades) external {
        address caller = _msgSender();
        for (uint256 i = 0; i < _trades.length; i++) {
            Trade calldata trade = _trades[i];

            // Keyed on the signed EIP-712 digest of the trade, not the raw signature bytes. See _verifyTrade.
            _cancelSignature(_hashTypedDataV4(_hashTrade(trade)), caller);
        }
    }

    /// @notice Accept a list of Trades.
    /// @param _trades The list of Trades to accept.
    function accept(Trade[] calldata _trades) external whenNotPaused nonReentrant {
        address caller = _msgSender();

        for (uint256 i = 0; i < _trades.length; i++) {
            bytes32 tradeDigest = _verifyTrade(_trades[i], caller);

            _accept(_trades[i], caller, tradeDigest);
        }
    }

    /// @notice Returns the trade id for a given Trade.
    /// @param _trade The Trade to get the id from.
    /// @param _caller The address that called the contract.
    ///
    /// @dev The trade id is composed of hashing the following values:
    /// Salt + Caller + Received Assets (Contract Address + Value)
    function getTradeId(Trade calldata _trade, address _caller) public pure returns (bytes32) {
        bytes32 tradeId = keccak256(abi.encodePacked(_trade.checks.salt, _caller));

        for (uint256 i = 0; i < _trade.received.length; i++) {
            Asset calldata asset = _trade.received[i];

            tradeId = keccak256(abi.encodePacked(tradeId, asset.contractAddress, asset.value));
        }

        return tradeId;
    }

    /// @dev Accepts a Trade.
    /// This function is internal to allow child contracts to use it in their own accept function.
    /// Does not perform any checks, only transfers the assets and emits the Traded event.
    /// @param _tradeDigest The signed EIP-712 digest of the trade, as returned by `_verifyTrade`. Passed in
    /// because `_trade` gets modified and would no longer hash to the signed digest.
    function _accept(Trade memory _trade, address _caller, bytes32 _tradeDigest) internal {
        _modifyTrade(_trade);

        bytes32 hashedSignature = keccak256(_trade.signature);
        address signer = _trade.signer;

        _transferAssets(_trade.sent, signer, _caller, signer, _caller);
        _transferAssets(_trade.received, _caller, signer, signer, _caller);

        emit Traded(_caller, hashedSignature, _tradeDigest, _trade);
    }

    /// @dev Verifies that the Trade passes all checks and the signature is valid.
    /// @return tradeDigest The signed EIP-712 digest of the trade (the key cancellation/uses are tracked under).
    function _verifyTrade(Trade calldata _trade, address _caller) internal returns (bytes32 tradeDigest) {
        address signer = _trade.signer;
        bytes32 tradeId = getTradeId(_trade, _caller);
        tradeDigest = _hashTypedDataV4(_hashTrade(_trade));
        bytes32 hashedTradeWithSigner = keccak256(abi.encode(signer, tradeDigest));
        uint256 currentSignatureUses = signatureUses[hashedTradeWithSigner];

        if (usedTradeIds[tradeId]) {
            revert UsedTradeId();
        }

        _verifyChecks(_trade.checks, hashedTradeWithSigner, currentSignatureUses, signer, _caller);
        _verifyTradeSignature(_trade, signer);

        if (currentSignatureUses + 1 == _trade.checks.uses) {
            usedTradeIds[tradeId] = true;
        }

        signatureUses[hashedTradeWithSigner]++;
    }

    /// @dev Verifies that the Trade signature is valid.
    function _verifyTradeSignature(Trade calldata _trade, address _signer) private view {
        _verifySignature(_hashTrade(_trade), _trade.signature, _signer);
    }

    /// @dev Transfers all the provided assets using the overridden _transferAsset function.
    /// Updates all the asset beneficiaries to the provided _to address in case the original beneficiary is the 0 address.
    function _transferAssets(Asset[] memory _assets, address _from, address _to, address _signer, address _caller) private {
        for (uint256 i = 0; i < _assets.length; i++) {
            Asset memory asset = _assets[i];

            if (asset.beneficiary == address(0)) {
                asset.beneficiary = _to;
            }

            _transferAsset(asset, _from, _signer, _caller);
        }
    }

    /// @dev Allows the child contract to update the Trade before accepting it.
    function _modifyTrade(Trade memory _trade) internal view virtual;

    /// @dev Allows the child contract to handle the transfer of assets.
    function _transferAsset(Asset memory _asset, address _from, address _signer, address _caller) internal virtual;
}
