// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IManaUsdRateProvider {
    function getManaUsdRate() external view returns (uint256);
}
