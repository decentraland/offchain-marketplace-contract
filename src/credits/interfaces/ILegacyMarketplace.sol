// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ILegacyMarketplace {
    function safeExecuteOrder(address _contractAddress, uint256 _tokenId, uint256 _price, bytes memory _fingerprint) external;
    function executeOrder(address _contractAddress, uint256 _tokenId, uint256 _price) external;
}
