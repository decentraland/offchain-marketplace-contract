// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Contract that abstracts the storage of the fee collector and fee rate used by Marketplace contracts.
abstract contract FeeCollector {
    /// @notice The address that will receive the fees.
    address public feeCollector;
    /// @notice The rate at which the fees will be charged. 25_000 is 2.5%
    uint256 public feeRate;

    event FeeCollectorUpdated(address indexed _caller, address indexed _feeCollector);
    event FeeRateUpdated(address indexed _caller, uint256 _feeRate);

    constructor(address _feeCollector, uint256 _feeRate) {
        _updateFeeCollector(msg.sender, _feeCollector);
        _updateFeeRate(msg.sender, _feeRate);
    }

    /// @dev Updates the fee collector address.
    /// @param _caller The address of the user updating the collector.
    /// @param _feeCollector The new address of the fee collector.
    function _updateFeeCollector(address _caller, address _feeCollector) internal {
        feeCollector = _feeCollector;

        emit FeeCollectorUpdated(_caller, _feeCollector);
    }

    /// @dev Updates the fee rate.
    /// @param _caller The address of the user updating the rate.
    /// @param _feeRate The new fee rate.
    function _updateFeeRate(address _caller, uint256 _feeRate) internal {
        feeRate = _feeRate;

        emit FeeRateUpdated(_caller, _feeRate);
    }
}
